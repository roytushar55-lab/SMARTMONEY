using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.MarkWithdrawalPaid;

/// <summary>Null result means the withdrawal was not found.</summary>
public sealed class MarkWithdrawalPaidCommand : ICommand<WithdrawalDecisionResponse?>
{
    public Guid WithdrawalId { get; }

    public Guid ReviewerId { get; }

    /// <summary>The bank's UTR or transaction id.</summary>
    public string TransactionReference { get; }

    public MarkWithdrawalPaidCommand(
        Guid withdrawalId,
        Guid reviewerId,
        string transactionReference)
    {
        WithdrawalId = withdrawalId;
        ReviewerId = reviewerId;
        TransactionReference = transactionReference;
    }
}
