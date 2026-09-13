using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Offers;

namespace SmartMoney.Application.Features.Offers.ListOffersAdmin;

public sealed class ListOffersAdminQuery : IQuery<IReadOnlyList<OfferAdminResponse>>
{
    /// <summary>Optional — restricts the listing to one store.</summary>
    public Guid? StoreId { get; }

    public ListOffersAdminQuery(Guid? storeId)
    {
        StoreId = storeId;
    }
}
