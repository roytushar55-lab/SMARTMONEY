namespace SmartMoney.Application.Contracts.Withdrawals;

/// <summary>The numbers on top of the admin withdrawals page.</summary>
public sealed class AdminWithdrawalSummaryResponse
{
    /// <summary>Requested: waiting for an admin to approve or decline.</summary>
    public int ToDecide { get; set; }

    /// <summary>What the users in <see cref="ToDecide"/> would receive, in rupees.</summary>
    public decimal ToDecideAmount { get; set; }

    /// <summary>Approved: cleared, waiting to be paid.</summary>
    public int ToPay { get; set; }

    /// <summary>What still has to be paid out to those users, in rupees.</summary>
    public decimal ToPayAmount { get; set; }

    /// <summary>Processing: with a payout provider.</summary>
    public int InProgress { get; set; }

    /// <summary>Paid, failed, declined or cancelled.</summary>
    public int History { get; set; }

    /// <summary>Flagged for an admin to look at, in any status.</summary>
    public int NeedsAttention { get; set; }

    /// <summary>How many were paid in the last 30 days.</summary>
    public int PaidLast30Days { get; set; }

    /// <summary>What users received in the last 30 days, in rupees.</summary>
    public decimal PaidLast30DaysAmount { get; set; }
}
