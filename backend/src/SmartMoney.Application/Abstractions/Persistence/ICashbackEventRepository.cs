using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface ICashbackEventRepository
{
    /// <summary>Adds a line to the audit trail; saved with the caller's unit of work.</summary>
    Task AddAsync(
        CashbackEvent cashbackEvent,
        CancellationToken cancellationToken = default);

    /// <summary>Oldest first, with the acting admin loaded. Read-only.</summary>
    Task<IReadOnlyList<CashbackEvent>> ListByCashbackIdAsync(
        Guid cashbackId,
        CancellationToken cancellationToken = default);
}
