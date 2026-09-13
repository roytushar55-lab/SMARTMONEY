namespace SmartMoney.Application.Contracts.CashbackSettings;

public sealed class UpdateCashbackOverrideRequest
{
    public decimal UserSharePercent { get; set; }

    public int ConfirmationWindowDays { get; set; }

    public bool IsActive { get; set; }
}
