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