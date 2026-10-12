using System.Linq.Expressions;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Cashbacks;

/// <summary>
/// The one definition of which queue a cashback belongs to. The rules are
/// expression trees so the database filters with them and the tests run the
/// very same rules over in-memory objects; <see cref="Classify"/> uses the
/// compiled expressions, so the page row and the queue count cannot disagree.
///
/// An undecided cashback is Pending or AwaitingAdminReview. The queues are
/// mutually exclusive, in this precedence: a cashback that was already
/// confirmed and is back under review is a reversal to decide whatever the
/// network says; otherwise the network's word sorts it.
/// </summary>
public static class CashbackQueues
{
    // Network statuses are compared trimmed and lower case. "Reversed" on a
    // sale that was never confirmed means the network took it back before we
    // paid anything, so it is handled like a rejection.
    private static readonly string[] RejectedStatuses =
        { "rejected", "cancelled", "canceled", "reversed" };

    private static readonly string[] ValidatedStatuses = { "validated", "paid" };

    private static readonly Expression<Func<Cashback, bool>> ReadyToApprove = cashback =>
        (cashback.Status == CashbackStatus.Pending || cashback.Status == CashbackStatus.AwaitingAdminReview)
        && cashback.ConfirmedDate == null
        && ValidatedStatuses.Contains(cashback.AffiliateConversion.NetworkStatus.Trim().ToLower());

    private static readonly Expression<Func<Cashback, bool>> ReversalsToDecide = cashback =>
        cashback.Status == CashbackStatus.AwaitingAdminReview
        && cashback.ConfirmedDate != null;

    private static readonly Expression<Func<Cashback, bool>> NetworkRejected = cashback =>
        (cashback.Status == CashbackStatus.Pending || cashback.Status == CashbackStatus.AwaitingAdminReview)
        && cashback.ConfirmedDate == null
        && RejectedStatuses.Contains(cashback.AffiliateConversion.NetworkStatus.Trim().ToLower());

    // Everything undecided that is not sorted above, so no undecided
    // cashback is ever missing from every queue.
    private static readonly Expression<Func<Cashback, bool>> WaitingOnNetwork = cashback =>
        (cashback.Status == CashbackStatus.Pending || cashback.Status == CashbackStatus.AwaitingAdminReview)
        && cashback.ConfirmedDate == null
        && !ValidatedStatuses.Contains(cashback.AffiliateConversion.NetworkStatus.Trim().ToLower())
        && !RejectedStatuses.Contains(cashback.AffiliateConversion.NetworkStatus.Trim().ToLower());

    private static readonly Expression<Func<Cashback, bool>> History = cashback =>
        cashback.Status != CashbackStatus.Pending
        && cashback.Status != CashbackStatus.AwaitingAdminReview;

    private static readonly Dictionary<CashbackQueue, Expression<Func<Cashback, bool>>> Rules = new()
    {
        [CashbackQueue.ReversalsToDecide] = ReversalsToDecide,
        [CashbackQueue.NetworkRejected] = NetworkRejected,
        [CashbackQueue.ReadyToApprove] = ReadyToApprove,
        [CashbackQueue.WaitingOnNetwork] = WaitingOnNetwork,
        [CashbackQueue.History] = History
    };

    private static readonly (CashbackQueue Queue, Func<Cashback, bool> Test)[] Compiled =
        Rules.Select(rule => (rule.Key, rule.Value.Compile())).ToArray();

    private static readonly Func<Cashback, bool> UndecidedTest = cashback =>
        cashback.Status == CashbackStatus.Pending
        || cashback.Status == CashbackStatus.AwaitingAdminReview;

    /// <summary>The rule for one queue.</summary>
    public static Expression<Func<Cashback, bool>> Matches(CashbackQueue queue)
    {
        return Rules[queue];
    }

    /// <summary>
    /// Undecided and past its expected confirmation date. Applies on top of
    /// the queues (a reversal to decide can be overdue too).
    /// </summary>
    public static Expression<Func<Cashback, bool>> Overdue(DateTime nowUtc)
    {
        return cashback =>
            (cashback.Status == CashbackStatus.Pending || cashback.Status == CashbackStatus.AwaitingAdminReview)
            && cashback.ExpectedConfirmationDate < nowUtc;
    }

    /// <summary>
    /// Confirmed cashback whose sale the network has not paid us for yet:
    /// money the user can already withdraw that has not reached us.
    /// </summary>
    public static Expression<Func<Cashback, bool>> ConfirmedNotPaidByNetwork { get; } = cashback =>
        cashback.Status == CashbackStatus.Confirmed
        && cashback.AffiliateConversion.NetworkStatus.Trim().ToLower() != "paid";

    /// <summary>The single queue this cashback is in. The conversion must be loaded.</summary>
    public static CashbackQueue Classify(Cashback cashback)
    {
        foreach (var (queue, test) in Compiled)
        {
            if (test(cashback))
            {
                return queue;
            }
        }

        // Unreachable: the five rules cover every status and network word.
        throw new InvalidOperationException("The cashback matches no queue.");
    }

    public static bool IsOverdue(Cashback cashback, DateTime nowUtc)
    {
        return UndecidedTest(cashback) && cashback.ExpectedConfirmationDate < nowUtc;
    }
}
