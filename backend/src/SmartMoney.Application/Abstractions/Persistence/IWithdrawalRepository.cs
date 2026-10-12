using System.Linq.Expressions;
using SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IWithdrawalRepository
{
    Task AddAsync(
        Withdrawal withdrawal,
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked, for handlers that mutate and save.</summary>
    Task<Withdrawal?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked.</summary>
    Task<Withdrawal?> GetByReferenceAsync(
        string reference,
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked.</summary>
    Task<Withdrawal?> GetByProviderReferenceAsync(
        string providerName,
        string providerReference,
        CancellationToken cancellationToken = default);

    /// <summary>Read-only, with the owning user loaded, for admin detail.</summary>
    Task<Withdrawal?> GetWithUserByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    /// <summary>Open means Requested, Approved or Processing.</summary>
    Task<int> CountOpenByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default);

    /// <summary>Newest first. Read-only.</summary>
    Task<IReadOnlyList<Withdrawal>> ListByUserIdAsync(
        Guid userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<int> CountByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Newest first, with users loaded. Read-only. An empty filter lists all.
    /// </summary>
    Task<IReadOnlyList<Withdrawal>> ListAsync(
        WithdrawalListFilter filter,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<int> CountAsync(
        WithdrawalListFilter filter,
        CancellationToken cancellationToken = default);

    /// <summary>How many withdrawals match the rule.</summary>
    Task<int> CountMatchingAsync(
        Expression<Func<Withdrawal, bool>> predicate,
        CancellationToken cancellationToken = default);

    /// <summary>Total payout (net) amount of the withdrawals that match the rule.</summary>
    Task<decimal> SumNetAmountAsync(
        Expression<Func<Withdrawal, bool>> predicate,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Ids only, oldest first, for the background worker (which loads each
    /// withdrawal itself, in its own scope, so nothing else is needed here and
    /// the encrypted destinations are never pulled into memory). When
    /// <paramref name="updatedBeforeUtc"/> is set only rows not touched since
    /// then are returned. When <paramref name="submissionAttemptsBelow"/> is
    /// set, rows that have used up their attempts are skipped, and when
    /// <paramref name="needsAttention"/> is set only rows with that flag value
    /// are returned; both keep rows waiting for a person from crowding newer
    /// withdrawals out of a batch.
    /// </summary>
    Task<IReadOnlyList<Guid>> ListIdsByStatusAsync(
        WithdrawalStatus status,
        DateTime? updatedBeforeUtc,
        int take,
        int? submissionAttemptsBelow = null,
        bool? needsAttention = null,
        CancellationToken cancellationToken = default);
}
