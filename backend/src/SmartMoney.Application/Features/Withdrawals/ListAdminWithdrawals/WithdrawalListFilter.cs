using System.Globalization;
using System.Linq.Expressions;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;

/// <summary>
/// What the admin withdrawals list is narrowed to. Every part is optional and
/// they combine with "and". Built into expression trees so the database does
/// the filtering and the tests can run the same rules in memory.
/// </summary>
public sealed class WithdrawalListFilter
{
    /// <summary>A raw status (what the dashboard cards link with).</summary>
    public WithdrawalStatus? Status { get; init; }

    public WithdrawalQueue? Queue { get; init; }

    public bool NeedsAttentionOnly { get; init; }

    /// <summary>
    /// Matches the user name or email, our reference, the provider reference
    /// or bank UTR, or an exact amount (requested or payout).
    /// </summary>
    public string? Search { get; init; }

    /// <summary>Requested at or after this instant (UTC).</summary>
    public DateTime? CreatedFrom { get; init; }

    /// <summary>Requested before this instant (UTC); exclusive.</summary>
    public DateTime? CreatedBefore { get; init; }

    public IReadOnlyList<Expression<Func<Withdrawal, bool>>> Predicates()
    {
        var predicates = new List<Expression<Func<Withdrawal, bool>>>();

        if (Status is WithdrawalStatus status)
        {
            predicates.Add(withdrawal => withdrawal.Status == status);
        }

        if (Queue is WithdrawalQueue queue)
        {
            predicates.Add(WithdrawalQueues.Matches(queue));
        }

        if (NeedsAttentionOnly)
        {
            predicates.Add(WithdrawalQueues.NeedsAttention);
        }

        if (CreatedFrom is DateTime from)
        {
            predicates.Add(withdrawal => withdrawal.CreatedAt >= from);
        }

        if (CreatedBefore is DateTime before)
        {
            predicates.Add(withdrawal => withdrawal.CreatedAt < before);
        }

        string term = (Search ?? string.Empty).Trim().ToLowerInvariant();

        if (term.Length > 0)
        {
            predicates.Add(SearchPredicate(term));
        }

        return predicates;
    }

    private static Expression<Func<Withdrawal, bool>> SearchPredicate(string term)
    {
        // "₹1,250.50" and "1250.5" both count as an amount.
        string numeric = term.Replace("₹", string.Empty).Replace("rs.", string.Empty)
            .Replace("rs", string.Empty).Trim();

        if (decimal.TryParse(
                numeric, NumberStyles.Number, CultureInfo.InvariantCulture, out decimal amount))
        {
            return withdrawal =>
                withdrawal.User.FullName.ToLower().Contains(term)
                || withdrawal.User.Email.ToLower().Contains(term)
                || withdrawal.Reference.ToLower().Contains(term)
                || (withdrawal.ProviderReference != null
                    && withdrawal.ProviderReference.ToLower().Contains(term))
                || withdrawal.Amount == amount
                || withdrawal.NetAmount == amount;
        }

        return withdrawal =>
            withdrawal.User.FullName.ToLower().Contains(term)
            || withdrawal.User.Email.ToLower().Contains(term)
            || withdrawal.Reference.ToLower().Contains(term)
            || (withdrawal.ProviderReference != null
                && withdrawal.ProviderReference.ToLower().Contains(term));
    }
}
