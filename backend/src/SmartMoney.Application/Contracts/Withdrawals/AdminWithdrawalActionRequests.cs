namespace SmartMoney.Application.Contracts.Withdrawals;

/// <summary>The reason is shown to the user, so keep it plain and kind.</summary>
public sealed class RejectWithdrawalRequest
{
    public string Reason { get; init; } = string.Empty;
}

/// <summary>For a manual payout: the bank's UTR or transaction id.</summary>
public sealed class MarkWithdrawalPaidRequest
{
    public string TransactionReference { get; init; } = string.Empty;
}

public sealed class MarkWithdrawalFailedRequest
{
    public string Reason { get; init; } = string.Empty;
}
