using SmartMoney.Domain.Common;

namespace SmartMoney.Domain.Entities;

public class Wallet : BaseEntity
{
    public Guid UserId { get; private set; }

    public decimal AvailableBalance { get; private set; }

    public decimal PendingBalance { get; private set; }

    public decimal TotalEarned { get; private set; }

    public decimal TotalWithdrawn { get; private set; }

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
    // negative) if the user already withdrew the funds — a negative-balance
    // policy is out of MVP scope.
    public void ReverseConfirmedCashback(decimal amount)
    {
        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (AvailableBalance < amount)
            throw new InvalidOperationException(
                "Insufficient available balance to reverse cashback.");

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