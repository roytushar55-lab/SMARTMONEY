using SmartMoney.Domain.Common;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Domain.Entities;

public class Cashback : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid WalletId { get; private set; }

    public Guid TransactionId { get; private set; }

    public decimal CommissionAmount { get; private set; }

    public decimal CashbackAmount { get; private set; }

    public CashbackStatus Status { get; private set; }

    public DateTime PurchaseDate { get; private set; }

    public DateTime ExpectedConfirmationDate { get; private set; }

    public DateTime? ConfirmedDate { get; private set; }

    public User User { get; private set; } = null!;

    public Wallet Wallet { get; private set; } = null!;

    private Cashback()
    {
    }

    public Cashback(
        Guid userId,
        Guid walletId,
        Guid transactionId,
        decimal commissionAmount,
        decimal cashbackAmount,
        DateTime purchaseDate,
        DateTime expectedConfirmationDate)
    {
        UserId = userId;
        WalletId = walletId;
        TransactionId = transactionId;
        CommissionAmount = commissionAmount;
        CashbackAmount = cashbackAmount;
        PurchaseDate = purchaseDate;
        ExpectedConfirmationDate = expectedConfirmationDate;

        Status = CashbackStatus.Pending;
    }

    public void Confirm()
    {
        if (Status != CashbackStatus.Pending)
            throw new InvalidOperationException("Only pending cashback can be confirmed.");

        Status = CashbackStatus.Confirmed;
        ConfirmedDate = DateTime.UtcNow;

        MarkAsUpdated();
    }

    public void Reject()
    {
        if (Status != CashbackStatus.Pending)
            throw new InvalidOperationException("Only pending cashback can be rejected.");

        Status = CashbackStatus.Rejected;

        MarkAsUpdated();
    }

    public void MarkAsPaid()
    {
        if (Status != CashbackStatus.Confirmed)
            throw new InvalidOperationException("Only confirmed cashback can be paid.");

        Status = CashbackStatus.Paid;

        MarkAsUpdated();
    }
}