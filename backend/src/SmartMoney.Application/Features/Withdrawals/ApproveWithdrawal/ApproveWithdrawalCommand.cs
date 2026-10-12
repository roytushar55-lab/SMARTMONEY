using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.ApproveWithdrawal;

/// <summary>Null result means the withdrawal was not found.</summary>
public sealed class ApproveWithdrawalCommand : ICommand<WithdrawalDecisionResponse?>
{
    public Guid WithdrawalId { get; }

    public Guid ReviewerId { get; }

    public ApproveWithdrawalCommand(Guid withdrawalId, Guid reviewerId)
    {
        WithdrawalId = withdrawalId;
        ReviewerId = reviewerId;
    }
}
