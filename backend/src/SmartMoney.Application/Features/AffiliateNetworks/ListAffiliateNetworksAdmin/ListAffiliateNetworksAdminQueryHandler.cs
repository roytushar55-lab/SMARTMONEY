using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.AffiliateNetworks;
using SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;

namespace SmartMoney.Application.Features.AffiliateNetworks.ListAffiliateNetworksAdmin;

public sealed class ListAffiliateNetworksAdminQueryHandler
    : IQueryHandler<ListAffiliateNetworksAdminQuery, IReadOnlyList<AffiliateNetworkAdminResponse>>
{
    private readonly IAffiliateNetworkRepository _networkRepository;

    public ListAffiliateNetworksAdminQueryHandler(IAffiliateNetworkRepository networkRepository)
    {
        _networkRepository = networkRepository;
    }

    public async Task<IReadOnlyList<AffiliateNetworkAdminResponse>> HandleAsync(
        ListAffiliateNetworksAdminQuery query,
        CancellationToken cancellationToken)
    {
        var networks = await _networkRepository.GetAllAsync(cancellationToken);

        return networks
            .Select(CreateAffiliateNetworkCommandHandler.ToResponse)
            .ToList();
    }
}
