using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;

namespace SmartMoney.Application.Features.StoreAffiliateMappings.ListStoreAffiliateMappingsAdmin;

public sealed class ListStoreAffiliateMappingsAdminQuery
    : IQuery<IReadOnlyList<StoreAffiliateMappingAdminResponse>>
{
    /// <summary>Optional — restricts the listing to one store.</summary>
    public Guid? StoreId { get; }

    public ListStoreAffiliateMappingsAdminQuery(Guid? storeId)
    {
        StoreId = storeId;
    }
}
