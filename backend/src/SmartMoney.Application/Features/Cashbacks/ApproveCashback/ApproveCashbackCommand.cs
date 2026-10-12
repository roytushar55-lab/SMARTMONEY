using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Cashbacks;

namespace SmartMoney.Application.Features.Cashbacks.ApproveCashback;

public sealed class ApproveCashbackCommand : ICommand<CashbackDecisionResponse?>
{
    public Guid CashbackId { get; }

    /// <summary>The admin making the decision, recorded in the audit trail.</summary>
    public Guid ReviewerId { get; }

    /// <summary>Why, in the admin's words. Optional for now.</summary>
    public string? Reason { get; }

    /// <summary>
    /// Approve even though the network has not validated the sale. The caller
    /// must already have checked the admin is a SuperAdmin; a reason is required.
    /// </summary>
    public bool Override { get; }

    public ApproveCashbackCommand(Guid cashbackId, Guid reviewerId, string? reason = null, bool @override = false)
    {
        CashbackId = cashbackId;
        ReviewerId = reviewerId;
        Reason = reason;
        Override = @override;
    }
}
