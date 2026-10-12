namespace SmartMoney.Application.Contracts.Cashbacks;

/// <summary>One line of a cashback's audit trail.</summary>
public sealed class CashbackEventResponse
{
    public Guid Id { get; set; }

    /// <summary>Created, NetworkStatusChanged, FlaggedForReview, Approved, Rejected or Reversed.</summary>
    public string Type { get; set; } = string.Empty;

    /// <summary>Null when the event came from the network.</summary>
    public Guid? ActorUserId { get; set; }

    public string? ActorName { get; set; }

    public string? ActorEmail { get; set; }

    public string? FromStatus { get; set; }

    public string ToStatus { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public string? NetworkStatus { get; set; }

    public string? Reason { get; set; }

    public DateTime CreatedAt { get; set; }
}
