namespace SmartMoney.Application.Contracts.Wallets;

public sealed class MyWalletResponse
{
    public decimal AvailableBalance { get; set; }

    public decimal PendingBalance { get; set; }

    /// <summary>Money reserved for open withdrawals; not spendable.</summary>
    public decimal HeldBalance { get; set; }

    public decimal TotalEarned { get; set; }

    public decimal TotalWithdrawn { get; set; }
}
