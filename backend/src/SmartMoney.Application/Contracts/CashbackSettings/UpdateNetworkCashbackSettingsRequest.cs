namespace SmartMoney.Application.Contracts.CashbackSettings;

public sealed class UpdateNetworkCashbackSettingsRequest
{
    public decimal UserSharePercent { get; set; }

    public int ConfirmationWindowDays { get; set; }
}
