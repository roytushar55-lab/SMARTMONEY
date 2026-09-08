using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Categories.UpdateCategory;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Categories;

public sealed class UpdateCategoryHandlerTests
{
    private readonly Mock<ICategoryRepository> _categories = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

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
}
