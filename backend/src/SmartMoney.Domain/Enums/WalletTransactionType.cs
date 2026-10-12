namespace SmartMoney.Domain.Enums;

/// <summary>
/// What a wallet ledger entry represents. The type alone determines which
/// balance bucket moved and in which direction; <c>Amount</c> is always
/// positive. M5 (withdrawals) extends this with withdrawal entries.
/// </summary>
public enum WalletTransactionType
{
    /// <summary>Cashback created — credited to PendingBalance.</summary>
    CashbackPending = 1,

    /// <summary>
    /// Admin confirmed — moved from PendingBalance to AvailableBalance and
    /// added to TotalEarned.
    /// </summary>
    CashbackConfirmed = 2,

    /// <summary>Admin rejected — removed from PendingBalance.</summary>
    CashbackRejected = 3,

    /// <summary>
    /// Admin reversed a previously confirmed cashback — debited from
    /// AvailableBalance and TotalEarned.
    /// </summary>
    CashbackReversed = 4,

    /// <summary>
    /// A withdrawal was requested — moved from AvailableBalance to
    /// HeldBalance so it cannot be spent twice.
    /// </summary>
    WithdrawalRequested = 5,

    /// <summary>
    /// The payout reached the user — removed from HeldBalance and added to
    /// TotalWithdrawn.
    /// </summary>
    WithdrawalCompleted = 6,

    /// <summary>
    /// The withdrawal failed, was rejected or cancelled — moved from
    /// HeldBalance back to AvailableBalance.
    /// </summary>
    WithdrawalReleased = 7
}
