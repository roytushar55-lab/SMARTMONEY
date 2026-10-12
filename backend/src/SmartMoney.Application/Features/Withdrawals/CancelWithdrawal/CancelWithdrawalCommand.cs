using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.CancelWithdrawal;

public sealed class CancelWithdrawalCommand : ICommand<WithdrawalDecisionResponse>
{
    public Guid UserId { get; }

    public Guid WithdrawalId { get; }

    public CancelWithdrawalCommand(Guid userId, Guid withdrawalId)
    {
        UserId = userId;
        WithdrawalId = withdrawalId;
    }
}
