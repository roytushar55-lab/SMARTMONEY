namespace SmartMoney.Domain.Entities;

/// <summary>
/// Most specific rung of the cashback resolution hierarchy: a rate override
/// for one store under one network, optionally narrowed to one category. A
/// row with <see cref="CategoryId"/> null applies to the whole store under
/// that network; a row with it set applies only to that store/category pair.
/// Unique on (AffiliateNetworkId, StoreId, CategoryId) — see
/// <c>CashbackRateOverrideConfiguration</c>.
/// </summary>
public sealed class CashbackRateOverride
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid AffiliateNetworkId { get; set; }

    public AffiliateNetwork AffiliateNetwork { get; set; } = null!;

    public Guid StoreId { get; set; }

    public Store Store { get; set; } = null!;

    public Guid? CategoryId { get; set; }

    public Category? Category { get; set; }

    /// <summary>
    /// Share of the network commission credited to the user, in percent
    /// (e.g. 60.00 = the user receives 60% of the commission).
    /// </summary>
    public decimal UserSharePercent { get; set; }

    /// <summary>
    /// Days after creation until a pending cashback is expected to confirm.
    /// </summary>
    public int ConfirmationWindowDays { get; set; }

    /// <summary>Disabled overrides are ignored by resolution without deleting the row.</summary>
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }
}
