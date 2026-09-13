namespace SmartMoney.Application.Contracts.CashbackSettings;

public sealed class CashbackRateOverrideResponse
{
    public Guid Id { get; set; }

    public Guid AffiliateNetworkId { get; set; }

    public Guid StoreId { get; set; }

    public string StoreName { get; set; } = string.Empty;

    public Guid? CategoryId { get; set; }

    public string? CategoryName { get; set; }

    public decimal UserSharePercent { get; set; }

    public int ConfirmationWindowDays { get; set; }

    public bool IsActive { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }
}
