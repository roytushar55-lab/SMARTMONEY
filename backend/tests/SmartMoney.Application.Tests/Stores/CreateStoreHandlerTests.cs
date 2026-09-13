using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Stores.CreateStore;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Stores;

public sealed class CreateStoreHandlerTests
{
    private readonly Mock<IStoreRepository> _stores = new();
    private readonly Mock<ICategoryRepository> _categories = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    public CreateStoreHandlerTests()
    {
        _categories.Setup(c => c.AllExistAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _stores.Setup(s => s.GetTrackedByDisplayOrderRangeAsync(
                It.IsAny<int>(), It.IsAny<int>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Store>());
    }

    private CreateStoreCommandHandler CreateHandler()
    {
        return new CreateStoreCommandHandler(
            _stores.Object, _categories.Object, new CreateStoreValidator(), _unitOfWork.Object);
    }

    private static CreateStoreCommand ValidCommand(IReadOnlyList<Guid>? categoryIds = null)
    {
        return new CreateStoreCommand(
            "Myntra", null, "short", "long", null, null,
            "https://www.myntra.com", "Up to 10%", true, 1,
            categoryIds ?? Array.Empty<Guid>());
    }

    [Fact]
    public async Task ValidRequest_CreatesStoreWithGeneratedSlug()
    {
        var response = await CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None);

        Assert.Equal("Myntra", response.Name);
        Assert.Equal("myntra", response.Slug);
        Assert.True(response.IsActive);
        _stores.Verify(
            s => s.AddAsync(It.IsAny<Store>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task CategoryIds_AttachedAsStoreCategories()
    {
        var categoryId = Guid.NewGuid();
        Store? created = null;
        _stores.Setup(s => s.AddAsync(It.IsAny<Store>(), It.IsAny<CancellationToken>()))
            .Callback<Store, CancellationToken>((s, _) => created = s);

        await CreateHandler().HandleAsync(ValidCommand(new[] { categoryId }), CancellationToken.None);

        Assert.NotNull(created);
        Assert.Single(created!.StoreCategories);
        Assert.Equal(categoryId, created.StoreCategories.First().CategoryId);
    }

    [Fact]
    public async Task UnknownCategoryId_ThrowsArgumentException()
    {
        _categories.Setup(c => c.AllExistAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(ValidCommand(new[] { Guid.NewGuid() }), CancellationToken.None));

        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task MissingWebsiteUrl_ThrowsArgumentException()
    {
        var command = new CreateStoreCommand(
            "Myntra", null, null, null, null, null, "", null, false, 0,
            Array.Empty<Guid>());

        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(command, CancellationToken.None));
    }

    [Fact]
    public async Task DuplicateName_ThrowsInvalidOperation()
    {
        _stores.Setup(s => s.NameExistsAsync("Myntra", null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None));
    }

    [Fact]
    public async Task Collision_ShiftsExistingSiblingsDown()
    {
        var atOne = new Store { Name = "Flipkart", Slug = "flipkart", WebsiteUrl = "https://flipkart.com", DisplayOrder = 1 };
        var atTwo = new Store { Name = "Amazon", Slug = "amazon", WebsiteUrl = "https://amazon.in", DisplayOrder = 2 };

        _stores.Setup(s => s.GetTrackedByDisplayOrderRangeAsync(
                1, int.MaxValue, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Store> { atOne, atTwo });

        var response = await CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None);

        Assert.Equal(1, response.DisplayOrder);
        Assert.Equal(2, atOne.DisplayOrder);
        Assert.Equal(3, atTwo.DisplayOrder);
    }
}
