namespace SmartMoney.Application.Features.Withdrawals;

/// <summary>
/// The work queues of the admin withdrawals page. Every withdrawal is in
/// exactly one, decided by its status alone. "Needs attention" is not a queue:
/// it is a flag that can sit on a withdrawal in any of them.
/// </summary>
public enum WithdrawalQueue
{
    /// <summary>Requested: waiting for an admin to approve or decline.</summary>
    ToDecide = 1,

    /// <summary>
    /// Approved: cleared for payout. With the manual provider this is where an
    /// admin pays the money and records the bank reference.
    /// </summary>
    ToPay = 2,

    /// <summary>Processing: sent to a payout provider, waiting for its answer.</summary>
    InProgress = 3,

    /// <summary>Settled: paid, failed, declined or cancelled.</summary>
    History = 4
}
