namespace SmartMoney.Domain.Enums;

/// <summary>
/// Lifecycle of a withdrawal. The money is held on the wallet from
/// <see cref="Requested"/> until the withdrawal reaches a terminal state:
/// <see cref="Completed"/> moves it to TotalWithdrawn, while
/// <see cref="Failed"/>, <see cref="Rejected"/> and <see cref="Cancelled"/>
/// release it back to the available balance.
/// </summary>
public enum WithdrawalStatus
{
    /// <summary>Created; funds held; waiting for an admin (if approval is required).</summary>
    Requested = 1,

    /// <summary>Cleared to be paid. Waits for the provider (or a manual payout).</summary>
    Approved = 2,

    /// <summary>Submitted to the payout provider; waiting for the final result.</summary>
    Processing = 3,

    /// <summary>Money reached the user. Terminal.</summary>
    Completed = 4,

    /// <summary>The payout failed. Funds released. Terminal.</summary>
    Failed = 5,

    /// <summary>An admin declined it. Funds released. Terminal.</summary>
    Rejected = 6,

    /// <summary>The user cancelled before approval. Funds released. Terminal.</summary>
    Cancelled = 7
}
