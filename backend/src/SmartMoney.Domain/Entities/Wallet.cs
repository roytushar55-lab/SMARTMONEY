using SmartMoney.Domain.Common;

namespace SmartMoney.Domain.Entities;

public class Wallet : BaseEntity
{
    public Guid UserId { get; private set; }

    public decimal AvailableBalance { get; private set; }

    public decimal PendingBalance { get; private set; }

    public decimal TotalEarned { get; private set; }

    public decimal TotalWithdrawn { get; private set; }

    /// <summary>
    /// Money reserved for withdrawals that are still open. It has left
    /// AvailableBalance (so it cannot be spent twice) but is not yet counted
    /// in TotalWithdrawn.
    /// </summary>
    public decimal HeldBalance { get; private set; }

    public User User { get; private set; } = null!;

    private Wallet()
    {
    }

    public Wallet(Guid userId)
    {
        UserId = userId;
    }

    public void AddPendingCashback(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        PendingBalance += amount;
        MarkAsUpdated();
    }

    public void ApproveCashback(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (PendingBalance < amount)
            throw new InvalidOperationException("Insufficient pending cashback.");

        PendingBalance -= amount;
        AvailableBalance += amount;
        TotalEarned += amount;

        MarkAsUpdated();
    }

    public void RemovePendingCashback(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (PendingBalance < amount)
            throw new InvalidOperationException("Insufficient pending cashback.");

        PendingBalance -= amount;
        MarkAsUpdated();
    }

    // Undoes a previously approved cashback. Fails (rather than going
    // negative) if the user already withdrew the funds, or has them held for
    // a pending withdrawal (the message says which) — a negative-balance
    // policy is out of MVP scope.
    public void ReverseConfirmedCashback(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (AvailableBalance < amount)
        {
            // Money reserved for a withdrawal is not spendable, but it is not
            // gone either: say so, because the admin's way forward differs
            // (decline or wait for the withdrawal, then reverse).
            if (AvailableBalance + HeldBalance >= amount)
                throw new InvalidOperationException(
                    $"₹{HeldBalance:0.##} of this wallet is held for a pending " +
                    "withdrawal, so the cashback cannot be reversed yet. Wait " +
                    "for the withdrawal to finish, or decline it, then reverse " +
                    "the cashback.");

            throw new InvalidOperationException(
                "Insufficient available balance to reverse cashback.");
        }

        AvailableBalance -= amount;
        TotalEarned -= amount;

        MarkAsUpdated();
    }

    /// <summary>
    /// Touches the row without changing balances so the optimistic-concurrency
    /// token is checked on save: account deletion reads the balance, and must
    /// fail (rather than delete a user whose wallet just got credited) if
    /// another request changed it in between.
    /// </summary>
    public void RecordAccountClosure()
    {
        MarkAsUpdated();
    }

    /// <summary>A withdrawal was requested: reserve the money.</summary>
    public void HoldForWithdrawal(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (AvailableBalance < amount)
            throw new InvalidOperationException("Insufficient wallet balance.");

        AvailableBalance -= amount;
        HeldBalance += amount;

        MarkAsUpdated();
    }

    /// <summary>The payout reached the user: the reserved money is now spent.</summary>
    public void CompleteWithdrawal(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (HeldBalance < amount)
            throw new InvalidOperationException(
                "Insufficient held balance to complete the withdrawal.");

        HeldBalance -= amount;
        TotalWithdrawn += amount;

        MarkAsUpdated();
    }

    /// <summary>The withdrawal failed, was rejected or cancelled: give the money back.</summary>
    public void ReleaseWithdrawalHold(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (HeldBalance < amount)
            throw new InvalidOperationException(
                "Insufficient held balance to release.");

        HeldBalance -= amount;
        AvailableBalance += amount;

        MarkAsUpdated();
    }

    public void Withdraw(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (AvailableBalance < amount)
            throw new InvalidOperationException("Insufficient wallet balance.");

        AvailableBalance -= amount;
        TotalWithdrawn += amount;

        MarkAsUpdated();
    }
}