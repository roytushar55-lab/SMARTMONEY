using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.AffiliateNetworks;

namespace SmartMoney.Application.Features.CashbackSettings.ListNetworks;

public sealed class ListNetworksQuery : IQuery<IReadOnlyList<AffiliateNetworkAdminResponse>>
{
}
