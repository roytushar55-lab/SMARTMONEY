using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.GetNetworkCashbackSettings;

public sealed class GetNetworkCashbackSettingsQuery : IQuery<NetworkCashbackSettingsDetailResponse?>
{
    public Guid AffiliateNetworkId { get; }

    public GetNetworkCashbackSettingsQuery(Guid affiliateNetworkId)
    {
        AffiliateNetworkId = affiliateNetworkId;
    }
}
