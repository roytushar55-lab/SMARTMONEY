using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface ICashbackSettingsRepository
{
    /// <summary>
    /// Returns the single policy row. Null only when the database was never
    /// seeded; callers should treat that as "cashback generation disabled".
    /// </summary>
    Task<CashbackSettings?> GetAsync(CancellationToken cancellationToken = default);

    /// <summary>Change-tracked — for the admin update handler to mutate and save.</summary>
    Task<CashbackSettings?> GetTrackedAsync(CancellationToken cancellationToken = default);
}
