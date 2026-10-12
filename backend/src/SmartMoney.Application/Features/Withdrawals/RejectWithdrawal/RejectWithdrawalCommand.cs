using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.RejectWithdrawal;

/// <summary>Null result means the withdrawal was not found.</summary>
public sealed class RejectWithdrawalCommand : ICommand<WithdrawalDecisionResponse?>
{
    public Guid WithdrawalId { get; }

    public Guid ReviewerId { get; }

    /// <summary>Shown to the user.</summary>
    public string Reason { get; }

    public RejectWithdrawalCommand(Guid withdrawalId, Guid reviewerId, string reason)
    {
        WithdrawalId = withdrawalId;
        ReviewerId = reviewerId;
        Reason = reason;
    }
}
