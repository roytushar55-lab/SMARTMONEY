namespace SmartMoney.Domain.Entities;

/// <summary>
/// Per-network cashback policy — one row per <see cref="AffiliateNetwork"/>.
/// Sits between the system-wide <see cref="CashbackSettings"/> fallback and
/// per-store/category <see cref="CashbackRateOverride"/> rows in the
/// resolution hierarchy: system -> network -> store/category override.
/// </summary>
public sealed class NetworkCashbackSettings
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid AffiliateNetworkId { get; set; }

    public AffiliateNetwork AffiliateNetwork { get; set; } = null!;

    /// <summary>
    /// Share of the network commission credited to the user, in percent
    /// (e.g. 60.00 = the user receives 60% of the commission).
    /// </summary>
    public decimal UserSharePercent { get; set; }

    /// <summary>
    /// Days after creation until a pending cashback is expected to confirm.
    /// </summary>
    public int ConfirmationWindowDays { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }
}
