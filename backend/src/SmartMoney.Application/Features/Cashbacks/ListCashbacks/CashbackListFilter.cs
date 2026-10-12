using System.Globalization;
using System.Linq.Expressions;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Cashbacks.ListCashbacks;

/// <summary>
/// What the admin review list is narrowed to. Every part is optional and they
/// combine with "and". Built into expression trees so the database does the
/// filtering and the tests can run the same rules in memory.
/// </summary>
public sealed class CashbackListFilter
{
    /// <summary>The raw status (what the dashboard cards link with).</summary>
    public CashbackStatus? Status { get; init; }

    public CashbackQueue? Queue { get; init; }

    /// <summary>Only undecided cashbacks past their expected confirmation date.</summary>
    public bool OverdueOnly { get; init; }

    /// <summary>Matches the user's name or email, the store name, or an exact amount.</summary>
    public string? Search { get; init; }

    /// <summary>Created at or after this instant (UTC).</summary>
    public DateTime? CreatedFrom { get; init; }

    /// <summary>Created before this instant (UTC); exclusive, so a whole day is [midnight, next midnight).</summary>
    public DateTime? CreatedBefore { get; init; }

    /// <summary>The moment "overdue" is measured against.</summary>
    public DateTime NowUtc { get; init; } = DateTime.UtcNow;

    public IReadOnlyList<Expression<Func<Cashback, bool>>> Predicates()
    {
        var predicates = new List<Expression<Func<Cashback, bool>>>();

        if (Status is CashbackStatus status)
        {
            predicates.Add(cashback => cashback.Status == status);
        }

        if (Queue is CashbackQueue queue)
        {
            predicates.Add(CashbackQueues.Matches(queue));
        }

        if (OverdueOnly)
        {
            predicates.Add(CashbackQueues.Overdue(NowUtc));
        }

        if (CreatedFrom is DateTime from)
        {
            predicates.Add(cashback => cashback.CreatedAt >= from);
        }

        if (CreatedBefore is DateTime before)
        {
            predicates.Add(cashback => cashback.CreatedAt < before);
        }

        string term = (Search ?? string.Empty).Trim().ToLowerInvariant();

        if (term.Length > 0)
        {
            predicates.Add(SearchPredicate(term));
        }

        return predicates;
    }

    private static Expression<Func<Cashback, bool>> SearchPredicate(string term)
    {
        // "₹1,250.50" and "1250.5" both count as an amount.
        string numeric = term.Replace("₹", string.Empty).Replace("rs.", string.Empty)
            .Replace("rs", string.Empty).Trim();

        if (decimal.TryParse(
                numeric, NumberStyles.Number, CultureInfo.InvariantCulture, out decimal amount))
        {
            return cashback =>
                cashback.User.FullName.ToLower().Contains(term)
                || cashback.User.Email.ToLower().Contains(term)
                || (cashback.AffiliateConversion.AffiliateClick != null
                    && cashback.AffiliateConversion.AffiliateClick.Store != null
                    && cashback.AffiliateConversion.AffiliateClick.Store.Name.ToLower().Contains(term))
                || cashback.CashbackAmount == amount
                || cashback.AffiliateConversion.OrderAmount == amount
                || cashback.AffiliateConversion.CommissionAmount == amount;
        }

        return cashback =>
            cashback.User.FullName.ToLower().Contains(term)
            || cashback.User.Email.ToLower().Contains(term)
            || (cashback.AffiliateConversion.AffiliateClick != null
                && cashback.AffiliateConversion.AffiliateClick.Store != null
                && cashback.AffiliateConversion.AffiliateClick.Store.Name.ToLower().Contains(term));
    }
}
