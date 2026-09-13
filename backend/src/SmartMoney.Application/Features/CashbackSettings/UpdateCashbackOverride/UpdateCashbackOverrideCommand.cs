using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.UpdateCashbackOverride;

public sealed class UpdateCashbackOverrideCommand : ICommand<CashbackRateOverrideResponse?>
{
    public Guid AffiliateNetworkId { get; }

    public Guid OverrideId { get; }

    public decimal UserSharePercent { get; }

    public int ConfirmationWindowDays { get; }

    public bool IsActive { get; }

    public UpdateCashbackOverrideCommand(
        Guid affiliateNetworkId,
        Guid overrideId,
        decimal userSharePercent,
        int confirmationWindowDays,
        bool isActive)
    {
        AffiliateNetworkId = affiliateNetworkId;
        OverrideId = overrideId;
        UserSharePercent = userSharePercent;
        ConfirmationWindowDays = confirmationWindowDays;
        IsActive = isActive;
    }
}
