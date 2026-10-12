namespace SmartMoney.Application.Features.Cashbacks;

/// <summary>
/// The work queues of the admin review page. Every cashback is in exactly one.
/// "Overdue" is not a queue: it is a flag on an undecided cashback whose
/// expected confirmation date has passed (see <see cref="CashbackQueues.Overdue"/>).
/// </summary>
public enum CashbackQueue
{
    /// <summary>Not decided, and the network says validated or paid: safe to approve.</summary>
    ReadyToApprove = 1,

    /// <summary>Already confirmed, and the network has since reversed or rejected it.</summary>
    ReversalsToDecide = 2,

    /// <summary>Not decided, and the network says rejected, cancelled or reversed.</summary>
    NetworkRejected = 3,

    /// <summary>Not decided, and the network has not given a decisive answer yet.</summary>
    WaitingOnNetwork = 4,

    /// <summary>Decided: confirmed, rejected, reversed or paid out.</summary>
    History = 5
}
