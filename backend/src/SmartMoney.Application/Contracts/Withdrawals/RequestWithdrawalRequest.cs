namespace SmartMoney.Application.Contracts.Withdrawals;

/// <summary>
/// Body of POST api/withdrawals. Send the fields that match
/// <see cref="Method"/>: UpiId for "Upi"; BankAccountNumber and IfscCode for
/// "BankTransfer". Password re-confirms the user before money moves.
/// </summary>
public sealed class RequestWithdrawalRequest
{
    public decimal Amount { get; init; }

    /// <summary>"Upi" or "BankTransfer".</summary>
    public string Method { get; init; } = string.Empty;

    /// <summary>The name on the bank account or UPI handle.</summary>
    public string BeneficiaryName { get; init; } = string.Empty;

    public string? UpiId { get; init; }

    public string? BankAccountNumber { get; init; }

    public string? IfscCode { get; init; }

    public string Password { get; init; } = string.Empty;
}
