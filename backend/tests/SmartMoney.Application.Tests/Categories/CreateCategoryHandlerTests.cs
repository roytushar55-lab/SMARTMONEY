using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Categories.CreateCategory;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Categories;

public sealed class CreateCategoryHandlerTests
{
    private readonly Mock<ICategoryRepository> _categories = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    public CreateCategoryHandlerTests()
    {
        _categories.Setup(c => c.GetTrackedByDisplayOrderRangeAsync(
                It.IsAny<int>(), It.IsAny<int>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Category>());
    }

    private CreateCategoryCommandHandler CreateHandler()
    {
        return new CreateCategoryCommandHandler(
            _categories.Object, new CreateCategoryValidator(), _unitOfWork.Object);
    }

    [Fact]
    public async Task ValidRequest_GeneratesSlugAndCreates()
    {
        var command = new CreateCategoryCommand("Fashion & Style", null, "desc", null, 1);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Equal("Fashion & Style", response.Name);
        Assert.Equal("fashion-style", response.Slug);
        Assert.True(response.IsActive);
        _categories.Verify(
            c => c.AddAsync(It.IsAny<Category>(), It.IsAny<CancellationToken>()),
            Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ExplicitSlug_IsUsedVerbatimLowercased()
    {
        var command = new CreateCategoryCommand("Fashion", "CUSTOM-SLUG", null, null, 0);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Equal("custom-slug", response.Slug);
    }

    [Fact]
    public async Task MissingName_ThrowsArgumentException()
    {
        var command = new CreateCategoryCommand("", null, null, null, 0);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(command, CancellationToken.None));

        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateName_ThrowsInvalidOperation()
    {
        _categories.Setup(c => c.NameExistsAsync("Fashion", null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var command = new CreateCategoryCommand("Fashion", null, null, null, 0);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(command, CancellationToken.None));

        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateSlug_ThrowsInvalidOperation()
    {
        _categories.Setup(c => c.SlugExistsAsync("fashion", null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var command = new CreateCategoryCommand("Fashion", null, null, null, 0);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(command, CancellationToken.None));
    }

    [Fact]
    public async Task Collision_ShiftsExistingSiblingsDown()
    {
        var atTwo = new Category { Name = "Electronics", Slug = "electronics", DisplayOrder = 2 };
        var atThree = new Category { Name = "Travel", Slug = "travel", DisplayOrder = 3 };

        _categories.Setup(c => c.GetTrackedByDisplayOrderRangeAsync(
                2, int.MaxValue, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Category> { atTwo, atThree });

        var command = new CreateCategoryCommand("Fashion", null, null, null, 2);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Equal(2, response.DisplayOrder);
        Assert.Equal(3, atTwo.DisplayOrder);
        Assert.Equal(4, atThree.DisplayOrder);
    }
}
