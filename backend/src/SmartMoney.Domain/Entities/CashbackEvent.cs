using SmartMoney.Domain.Common;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Domain.Entities;

/// <summary>
/// One immutable line in a cashback's audit trail: what happened, who did it
/// (an admin, or nobody when it came from the network), what the cashback's
/// status was before and after, the amount, the network's status at the time,
/// and the reason an admin gave. Rows are only ever added.
/// </summary>
public class CashbackEvent : BaseEntity
{
    public const int MaxReasonLength = 500;

    public Guid CashbackId { get; private set; }

    public CashbackEventType Type { get; private set; }

    /// <summary>The admin who acted. Null for events that come from the network.</summary>
    public Guid? ActorUserId { get; private set; }

    /// <summary>Null when the cashback was just created.</summary>
    public CashbackStatus? FromStatus { get; private set; }

    public CashbackStatus ToStatus { get; private set; }

    /// <summary>The cashback amount at the time of the event.</summary>
    public decimal Amount { get; private set; }

    /// <summary>The affiliate network's status for the sale at the time, verbatim.</summary>
    public string? NetworkStatus { get; private set; }

    /// <summary>Why an admin decided as they did. Optional for now.</summary>
    public string? Reason { get; private set; }

    public Cashback Cashback { get; private set; } = null!;

    public User? Actor { get; private set; }

    private CashbackEvent()
    {
    }

    public CashbackEvent(
        Guid cashbackId,
        CashbackEventType type,
        Guid? actorUserId,
        CashbackStatus? fromStatus,
        CashbackStatus toStatus,
        decimal amount,
        string? networkStatus,
        string? reason)
    {
        if (cashbackId == Guid.Empty)
            throw new ArgumentException("A cashback is required.");

        string? cleanReason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();

        if (cleanReason is { Length: > MaxReasonLength })
            throw new ArgumentException(
                $"The reason can be at most {MaxReasonLength} characters.");

        CashbackId = cashbackId;
        Type = type;
        ActorUserId = actorUserId;
        FromStatus = fromStatus;
        ToStatus = toStatus;
        Amount = amount;
        NetworkStatus = string.IsNullOrWhiteSpace(networkStatus) ? null : networkStatus.Trim();
        Reason = cleanReason;
    }
}
