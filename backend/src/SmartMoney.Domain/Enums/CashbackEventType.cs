namespace SmartMoney.Domain.Enums;

/// <summary>What happened to a cashback, as recorded in its audit trail.</summary>
public enum CashbackEventType
{
    /// <summary>The cashback was created from a network report.</summary>
    Created = 1,

    /// <summary>The network reported a different status for the sale.</summary>
    NetworkStatusChanged = 2,

    /// <summary>A decisive network status parked the cashback for an admin.</summary>
    FlaggedForReview = 3,

    /// <summary>An admin confirmed it.</summary>
    Approved = 4,

    /// <summary>An admin rejected it.</summary>
    Rejected = 5,

    /// <summary>An admin reversed a confirmed cashback.</summary>
    Reversed = 6,

    /// <summary>A SuperAdmin approved it although the network did not say validated.</summary>
    ApprovedByOverride = 7
}
