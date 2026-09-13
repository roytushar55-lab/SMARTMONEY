namespace SmartMoney.Application.Contracts.CashbackSettings;

public sealed class NetworkCashbackSettingsResponse
{
    public Guid AffiliateNetworkId { get; set; }

    public decimal UserSharePercent { get; set; }

    public int ConfirmationWindowDays { get; set; }

    public DateTime? UpdatedAt { get; set; }
}
