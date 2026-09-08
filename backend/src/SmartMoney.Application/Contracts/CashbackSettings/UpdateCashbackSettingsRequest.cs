namespace SmartMoney.Application.Contracts.CashbackSettings;

public sealed class UpdateCashbackSettingsRequest
{
    public decimal UserSharePercent { get; set; }

    public int ConfirmationWindowDays { get; set; }
}
