using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Stores.UpdateStore;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Stores;

public sealed class UpdateStoreHandlerTests
{
    private readonly Mock<IStoreRepository> _stores = new();
    private readonly Mock<ICategoryRepository> _categories = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    public UpdateStoreHandlerTests()
    {
        _categories.Setup(c => c.AllExistAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
    }

    private UpdateStoreCommandHandler CreateHandler()
    {
        return new UpdateStoreCommandHandler(
            _stores.Object, _categories.Object, new UpdateStoreValidator(), _unitOfWork.Object);
    }

    private Store ExistingStore(params Guid[] existingCategoryIds)
    {
        var store = new Store
        {
            Name = "Myntra",
            Slug = "myntra",
            WebsiteUrl = "https://www.myntra.com",
            IsActive = true
        };

        foreach (var categoryId in existingCategoryIds)
        {
            store.StoreCategories.Add(new StoreCategory { StoreId = store.Id, CategoryId = categoryId });
        }

        _stores.Setup(s => s.GetByIdAsync(store.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(store);

        return store;
    }

    private static UpdateStoreCommand CommandFor(Store store, IReadOnlyList<Guid> categoryIds, bool isActive = true)
    {
        return new UpdateStoreCommand(
            store.Id, "Myntra Fashion", "myntra-fashion", null, null, null, null,
            "https://www.myntra.com", null, false, 2, isActive, categoryIds);
    }

    [Fact]
    public async Task ValidRequest_UpdatesFieldsAndDeactivateToggle()
    {
        var store = ExistingStore();

        var response = await CreateHandler().HandleAsync(
            CommandFor(store, Array.Empty<Guid>(), isActive: false), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("Myntra Fashion", response!.Name);
        Assert.False(response.IsActive);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task CategorySync_AddsAndRemovesToMatchRequestedSet()
    {
        var keep = Guid.NewGuid();
        var remove = Guid.NewGuid();
        var add = Guid.NewGuid();
        var store = ExistingStore(keep, remove);

        var response = await CreateHandler().HandleAsync(
            CommandFor(store, new[] { keep, add }), CancellationToken.None);

        Assert.NotNull(response);
        var resultIds = response!.CategoryIds.OrderBy(id => id).ToList();
        var expectedIds = new[] { keep, add }.OrderBy(id => id).ToList();
        Assert.Equal(expectedIds, resultIds);
    }

    [Fact]
    public async Task UnknownStore_ReturnsNull()
    {
        var command = new UpdateStoreCommand(
            Guid.NewGuid(), "Name", "slug", null, null, null, null,
            "https://example.com", null, false, 0, true, Array.Empty<Guid>());

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
