using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.UpdateNetworkCashbackSettings;

public sealed class UpdateNetworkCashbackSettingsCommand : ICommand<NetworkCashbackSettingsResponse?>
{
    public Guid AffiliateNetworkId { get; }

    public decimal UserSharePercent { get; }

    public int ConfirmationWindowDays { get; }

    public UpdateNetworkCashbackSettingsCommand(
        Guid affiliateNetworkId,
        decimal userSharePercent,
        int confirmationWindowDays)
    {
        AffiliateNetworkId = affiliateNetworkId;
        UserSharePercent = userSharePercent;
        ConfirmationWindowDays = confirmationWindowDays;
    }
}
