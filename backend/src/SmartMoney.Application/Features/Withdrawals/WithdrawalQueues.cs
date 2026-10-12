using System.Linq.Expressions;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals;

/// <summary>
/// The one definition of which queue a withdrawal is in. The rules are
/// expression trees so the database filters with them and the tests run the
/// very same rules over in-memory objects; <see cref="Classify"/> uses the
/// compiled expressions, so a row's queue and the queue's count cannot differ.
/// </summary>
public static class WithdrawalQueues
{
    private static readonly Dictionary<WithdrawalQueue, Expression<Func<Withdrawal, bool>>> Rules = new()
    {
        [WithdrawalQueue.ToDecide] = withdrawal => withdrawal.Status == WithdrawalStatus.Requested,
        [WithdrawalQueue.ToPay] = withdrawal => withdrawal.Status == WithdrawalStatus.Approved,
        [WithdrawalQueue.InProgress] = withdrawal => withdrawal.Status == WithdrawalStatus.Processing,
        [WithdrawalQueue.History] = withdrawal =>
            withdrawal.Status != WithdrawalStatus.Requested
            && withdrawal.Status != WithdrawalStatus.Approved
            && withdrawal.Status != WithdrawalStatus.Processing
    };

    private static readonly (WithdrawalQueue Queue, Func<Withdrawal, bool> Test)[] Compiled =
        Rules.Select(rule => (rule.Key, rule.Value.Compile())).ToArray();

    /// <summary>The rule for one queue.</summary>
    public static Expression<Func<Withdrawal, bool>> Matches(WithdrawalQueue queue)
    {
        return Rules[queue];
    }

    /// <summary>Flagged for an admin to look at, whatever the status.</summary>
    public static Expression<Func<Withdrawal, bool>> NeedsAttention { get; } =
        withdrawal => withdrawal.NeedsAttention;

    /// <summary>Paid to the user at or after <paramref name="sinceUtc"/>.</summary>
    public static Expression<Func<Withdrawal, bool>> PaidSince(DateTime sinceUtc)
    {
        return withdrawal =>
            withdrawal.Status == WithdrawalStatus.Completed
            && withdrawal.SettledAt >= sinceUtc;
    }

    /// <summary>The single queue this withdrawal is in.</summary>
    public static WithdrawalQueue Classify(Withdrawal withdrawal)
    {
        foreach (var (queue, test) in Compiled)
        {
            if (test(withdrawal))
            {
                return queue;
            }
        }

        // Unreachable: the four rules cover every status.
        throw new InvalidOperationException("The withdrawal matches no queue.");
    }
}
