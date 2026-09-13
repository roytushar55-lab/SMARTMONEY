using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface ICashbackRepository
{
    Task AddAsync(Cashback cashback, CancellationToken cancellationToken = default);

    /// <summary>
    /// Looks up the cashback attached to a conversion. Returned entity is
    /// change-tracked so callers can transition its status and save.
    /// </summary>
    Task<Cashback?> GetByConversionIdAsync(
        Guid affiliateConversionId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Change-tracked, no includes — used by admin decision handlers to
    /// transition status and save.
    /// </summary>
    Task<Cashback?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Admin review listing. Read-only; includes User and the conversion →
    /// click → store chain so the admin sees who earned it, from where, and
    /// the network's reported status. Null status lists all. Newest first.
    /// </summary>
    Task<IReadOnlyList<Cashback>> ListByStatusAsync(
        CashbackStatus? status,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<int> CountByStatusAsync(
        CashbackStatus? status,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// A user's own cashback history. Read-only; includes the conversion →
    /// click → store chain for display. Newest first.
    /// </summary>
    Task<IReadOnlyList<Cashback>> ListByUserIdAsync(
        Guid userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<int> CountByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Per-status cashback totals (row count + amount sum) for one user in a
    /// single grouped query — used by the admin user detail endpoint instead
    /// of one count+sum round-trip per status. A status with no cashbacks is
    /// simply absent from the result.
    /// </summary>
    Task<IReadOnlyDictionary<CashbackStatus, (int Count, decimal Amount)>> GetStatusSummaryByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default);
}
