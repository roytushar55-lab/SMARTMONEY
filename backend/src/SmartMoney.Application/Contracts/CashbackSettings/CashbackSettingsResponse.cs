namespace SmartMoney.Application.Contracts.CashbackSettings;

public sealed class CashbackSettingsResponse
{
    public decimal UserSharePercent { get; set; }

    public int ConfirmationWindowDays { get; set; }

    public DateTime? UpdatedAt { get; set; }
}
