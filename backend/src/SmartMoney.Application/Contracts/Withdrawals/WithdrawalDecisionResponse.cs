namespace SmartMoney.Application.Contracts.Withdrawals;

/// <summary>The result of an approve, reject, cancel or manual settle action.</summary>
public sealed class WithdrawalDecisionResponse
{
    public Guid WithdrawalId { get; set; }

    public string Reference { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;

    public decimal AvailableBalance { get; set; }

    public decimal HeldBalance { get; set; }
}
