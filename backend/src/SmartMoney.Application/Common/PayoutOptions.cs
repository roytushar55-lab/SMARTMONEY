namespace SmartMoney.Application.Common;

/// <summary>
/// Withdrawal rules, bound from the "Payouts" configuration section.
/// The fee values must match the chosen vendor's price list; the defaults
/// charge nothing so nothing is invented before a vendor is picked.
/// </summary>
public sealed class PayoutOptions
{
    public const string SectionName = "Payouts";

    /// <summary>"Manual" (admin pays and records it), "Fake" (Development only), or a vendor adapter name.</summary>
    public string Provider { get; set; } = "Manual";

    /// <summary>Smallest withdrawal, in rupees. Decided in the Terms of Service.</summary>
    public decimal MinimumAmount { get; set; } = 250m;

    /// <summary>Safety cap for one withdrawal, in rupees. Not yet a business decision; adjust.</summary>
    public decimal MaximumAmount { get; set; } = 50000m;

    /// <summary>The provider's flat fee per payout, before tax.</summary>
    public decimal FlatFee { get; set; }

    /// <summary>The provider's percentage fee, before tax (for example 0.5).</summary>
    public decimal PercentFee { get; set; }

    /// <summary>Tax charged on the provider's fee (GST).</summary>
    public decimal FeeTaxPercent { get; set; } = 18m;

    /// <summary>The user's share of the total fee. The Terms say 50.</summary>
    public decimal UserFeeSharePercent { get; set; } = 50m;

    /// <summary>When true an admin must approve every withdrawal.</summary>
    public bool RequireAdminApproval { get; set; } = true;

    public int MaxOpenWithdrawalsPerUser { get; set; } = 1;

    /// <summary>After this many temporary failures a withdrawal stops retrying and waits for an admin.</summary>
    public int MaxSubmissionAttempts { get; set; } = 5;

    public int WorkerIntervalSeconds { get; set; } = 60;

    public int WorkerBatchSize { get; set; } = 25;

    /// <summary>How long a payout may sit in Processing before the worker asks the provider.</summary>
    public int ReconcileAfterMinutes { get; set; } = 15;
}
