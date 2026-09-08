using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Offers;
using SmartMoney.Application.Features.Offers.CreateOffer;

namespace SmartMoney.Application.Features.Offers.ListOffersAdmin;

/// <summary>Admin listing — every offer, active and inactive, any date window.</summary>
public sealed class ListOffersAdminQueryHandler
    : IQueryHandler<ListOffersAdminQuery, IReadOnlyList<OfferAdminResponse>>
{
    private readonly IOfferRepository _offerRepository;

    public ListOffersAdminQueryHandler(IOfferRepository offerRepository)
    {
        _offerRepository = offerRepository;
    }

    public async Task<IReadOnlyList<OfferAdminResponse>> HandleAsync(
        ListOffersAdminQuery query,
        CancellationToken cancellationToken)
    {
        var offers = await _offerRepository.GetAllAsync(query.StoreId, cancellationToken);

        return offers
            .Select(offer => CreateOfferCommandHandler.ToResponse(offer, offer.Store.Name))
            .ToList();
    }
}
