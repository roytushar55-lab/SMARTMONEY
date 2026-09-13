using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.CreateCashbackOverride;

public sealed class CreateCashbackOverrideCommand : ICommand<CashbackRateOverrideResponse>
{
    public Guid AffiliateNetworkId { get; }

    public Guid StoreId { get; }

    public Guid? CategoryId { get; }

    public decimal UserSharePercent { get; }

    public int ConfirmationWindowDays { get; }

    public CreateCashbackOverrideCommand(
        Guid affiliateNetworkId,
        Guid storeId,
        Guid? categoryId,
        decimal userSharePercent,
        int confirmationWindowDays)
    {
        AffiliateNetworkId = affiliateNetworkId;
        StoreId = storeId;
        CategoryId = categoryId;
        UserSharePercent = userSharePercent;
        ConfirmationWindowDays = confirmationWindowDays;
    }
}
