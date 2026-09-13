namespace SmartMoney.Application.Contracts.CashbackSettings;

public sealed class CreateCashbackOverrideRequest
{
    public Guid StoreId { get; set; }

    public Guid? CategoryId { get; set; }

    public decimal UserSharePercent { get; set; }

    public int ConfirmationWindowDays { get; set; }
}
