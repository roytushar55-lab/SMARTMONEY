using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.AcknowledgeWithdrawal;

/// <summary>Null result means the withdrawal was not found.</summary>
public sealed class AcknowledgeWithdrawalCommand : ICommand<WithdrawalDecisionResponse?>
{
    public Guid WithdrawalId { get; }

    public AcknowledgeWithdrawalCommand(Guid withdrawalId)
    {
        WithdrawalId = withdrawalId;
    }
}
