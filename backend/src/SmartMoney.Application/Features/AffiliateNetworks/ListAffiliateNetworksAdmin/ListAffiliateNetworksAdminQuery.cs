using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.AffiliateNetworks;

namespace SmartMoney.Application.Features.AffiliateNetworks.ListAffiliateNetworksAdmin;

public sealed class ListAffiliateNetworksAdminQuery : IQuery<IReadOnlyList<AffiliateNetworkAdminResponse>>
{
}
