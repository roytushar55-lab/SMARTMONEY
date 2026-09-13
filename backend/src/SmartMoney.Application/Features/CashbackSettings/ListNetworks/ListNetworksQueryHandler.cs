using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.AffiliateNetworks;
using SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;

namespace SmartMoney.Application.Features.CashbackSettings.ListNetworks;

/// <summary>
/// Active affiliate networks for the hierarchical cashback settings screen —
/// only networks an admin could actually be tuning rates for.
/// </summary>
public sealed class ListNetworksQueryHandler
    : IQueryHandler<ListNetworksQuery, IReadOnlyList<AffiliateNetworkAdminResponse>>
{
    private readonly IAffiliateNetworkRepository _networkRepository;

    public ListNetworksQueryHandler(IAffiliateNetworkRepository networkRepository)
    {
        _networkRepository = networkRepository;
    }

    public async Task<IReadOnlyList<AffiliateNetworkAdminResponse>> HandleAsync(
        ListNetworksQuery query,
        CancellationToken cancellationToken)
    {
        var networks = await _networkRepository.GetAllAsync(cancellationToken);

        return networks
            .Where(network => network.IsActive)
            .Select(CreateAffiliateNetworkCommandHandler.ToResponse)
            .ToList();
    }
}
