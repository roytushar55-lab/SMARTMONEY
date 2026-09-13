using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Categories.UpdateCategory;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Categories;

public sealed class UpdateCategoryHandlerTests
{
    private readonly Mock<ICategoryRepository> _categories = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    public UpdateCategoryHandlerTests()
    {
        _categories.Setup(c => c.GetTrackedByDisplayOrderRangeAsync(
                It.IsAny<int>(), It.IsAny<int>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Category>());
    }

    private UpdateCategoryCommandHandler CreateHandler()
    {
        return new UpdateCategoryCommandHandler(
            _categories.Object, new UpdateCategoryValidator(), _unitOfWork.Object);
    }

    private Category ExistingCategory()
    {
        var category = new Category { Name = "Old Name", Slug = "old-name", IsActive = true };

        _categories.Setup(c => c.GetByIdAsync(category.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(category);

        return category;
    }

    [Fact]
    public async Task ValidRequest_UpdatesFields()
    {
        var category = ExistingCategory();

        var command = new UpdateCategoryCommand(
            category.Id, "New Name", "new-slug", "desc", "icon", 5, false);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("New Name", response!.Name);
        Assert.Equal("new-slug", response.Slug);
        Assert.False(response.IsActive);
        Assert.NotNull(category.UpdatedAt);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnknownCategory_ReturnsNull()
    {
        var command = new UpdateCategoryCommand(
            Guid.NewGuid(), "Name", "slug", null, null, 0, true);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateNameOnAnotherCategory_ThrowsInvalidOperation()
    {
        var category = ExistingCategory();
        _categories.Setup(c => c.NameExistsAsync("Taken", category.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var command = new UpdateCategoryCommand(
            category.Id, "Taken", "slug", null, null, 0, true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(command, CancellationToken.None));
    }

    [Fact]
    public async Task MoveDown_ShiftsIntermediateSiblingsUp()
    {
        var category = ExistingCategory();
        category.DisplayOrder = 1;

        var atTwo = new Category { Name = "A", Slug = "a", DisplayOrder = 2 };
        var atThree = new Category { Name = "B", Slug = "b", DisplayOrder = 3 };

        _categories.Setup(c => c.GetTrackedByDisplayOrderRangeAsync(
                1, 4, category.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Category> { atTwo, atThree });

        var command = new UpdateCategoryCommand(
            category.Id, "New Name", "new-slug", null, null, 4, true);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Equal(4, response!.DisplayOrder);
        Assert.Equal(1, atTwo.DisplayOrder);
        Assert.Equal(2, atThree.DisplayOrder);
    }

    [Fact]
    public async Task MoveUp_ShiftsIntermediateSiblingsDown()
    {
        var category = ExistingCategory();
        category.DisplayOrder = 4;

        var atOne = new Category { Name = "A", Slug = "a", DisplayOrder = 1 };
        var atTwo = new Category { Name = "B", Slug = "b", DisplayOrder = 2 };

        _categories.Setup(c => c.GetTrackedByDisplayOrderRangeAsync(
                1, 4, category.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Category> { atOne, atTwo });

        var command = new UpdateCategoryCommand(
            category.Id, "New Name", "new-slug", null, null, 1, true);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Equal(1, response!.DisplayOrder);
        Assert.Equal(2, atOne.DisplayOrder);
        Assert.Equal(3, atTwo.DisplayOrder);
    }

    [Fact]
    public async Task SameOrder_NoSiblingQueryOrShift()
    {
        var category = ExistingCategory();
        category.DisplayOrder = 5;

        var command = new UpdateCategoryCommand(
            category.Id, "New Name", "new-slug", null, null, 5, true);

        await CreateHandler().HandleAsync(command, CancellationToken.None);

        _categories.Verify(
            c => c.GetTrackedByDisplayOrderRangeAsync(
                It.IsAny<int>(), It.IsAny<int>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
