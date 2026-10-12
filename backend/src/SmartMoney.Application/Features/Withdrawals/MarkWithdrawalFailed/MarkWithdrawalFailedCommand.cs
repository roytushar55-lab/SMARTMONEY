using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.MarkWithdrawalFailed;

/// <summary>Null result means the withdrawal was not found.</summary>
public sealed class MarkWithdrawalFailedCommand : ICommand<WithdrawalDecisionResponse?>
{
    public Guid WithdrawalId { get; }

    /// <summary>Shown to the user.</summary>
    public string Reason { get; }

    public MarkWithdrawalFailedCommand(Guid withdrawalId, string reason)
    {
        WithdrawalId = withdrawalId;
        Reason = reason;
    }
}
