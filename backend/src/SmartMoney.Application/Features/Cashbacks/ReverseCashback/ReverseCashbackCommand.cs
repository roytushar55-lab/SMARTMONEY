using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Cashbacks;

namespace SmartMoney.Application.Features.Cashbacks.ReverseCashback;

public sealed class ReverseCashbackCommand : ICommand<CashbackDecisionResponse?>
{
    public Guid CashbackId { get; }

    /// <summary>The admin making the decision, recorded in the audit trail.</summary>
    public Guid ReviewerId { get; }

    /// <summary>Why, in the admin's words. Required, trimmed.</summary>
    public string Reason { get; }

    public ReverseCashbackCommand(Guid cashbackId, Guid reviewerId, string? reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
        {
            throw new ArgumentException("A reason is required to reverse a cashback.");
        }

        CashbackId = cashbackId;
        ReviewerId = reviewerId;
        Reason = reason.Trim();
    }
}
