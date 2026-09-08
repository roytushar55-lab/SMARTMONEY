using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Stores;
using SmartMoney.Application.Features.Stores.CreateStore;

namespace SmartMoney.Application.Features.Stores.ListStoresAdmin;

/// <summary>Admin listing — every store, active and inactive.</summary>
public sealed class ListStoresAdminQueryHandler
    : IQueryHandler<ListStoresAdminQuery, IReadOnlyList<StoreAdminResponse>>
{
    private readonly IStoreRepository _storeRepository;

    public ListStoresAdminQueryHandler(IStoreRepository storeRepository)
    {
        _storeRepository = storeRepository;
    }

    public async Task<IReadOnlyList<StoreAdminResponse>> HandleAsync(
        ListStoresAdminQuery query,
        CancellationToken cancellationToken)
    {
        var stores = await _storeRepository.GetAllAsync(cancellationToken);

        return stores
            .Select(CreateStoreCommandHandler.ToResponse)
            .ToList();
    }
}
