namespace SmartMoney.Application.Contracts.Cashbacks;

/// <summary>
/// Optional body of the approve, reject and reverse endpoints. The reason is
/// stored in the cashback's audit trail.
/// </summary>
public sealed class DecideCashbackRequest
{
    /// <summary>At most 500 characters.</summary>
    public string? Reason { get; set; }

    /// <summary>
    /// Approve even though the affiliate network has not validated the sale.
    /// SuperAdmin only, and a reason is required. Ignored by reject and reverse.
    /// </summary>
    public bool Override { get; set; }
}
