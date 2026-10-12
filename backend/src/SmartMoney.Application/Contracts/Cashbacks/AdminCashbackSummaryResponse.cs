namespace SmartMoney.Application.Contracts.Cashbacks;

/// <summary>The numbers on top of the admin review page.</summary>
public sealed class AdminCashbackSummaryResponse
{
    public int ReadyToApprove { get; set; }

    public int ReversalsToDecide { get; set; }

    public int NetworkRejected { get; set; }

    public int WaitingOnNetwork { get; set; }

    public int History { get; set; }

    /// <summary>Ready to approve, reversals to decide and network rejected: what needs a person now.</summary>
    public int NeedsDecision { get; set; }

    /// <summary>Undecided and past the expected confirmation date (any queue).</summary>
    public int Overdue { get; set; }

    /// <summary>
    /// Confirmed cashback the network has not paid us for yet, in rupees: money
    /// users can withdraw that has not reached Smart Money.
    /// </summary>
    public decimal ExposureAmount { get; set; }
}
