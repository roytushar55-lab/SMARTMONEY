using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface INetworkCashbackSettingsRepository
{
    /// <summary>Read-only — used by resolution and the admin GET.</summary>
    Task<NetworkCashbackSettings?> GetByNetworkIdAsync(
        Guid affiliateNetworkId,
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked — for the admin upsert handler to mutate and save.</summary>
    Task<NetworkCashbackSettings?> GetTrackedByNetworkIdAsync(
        Guid affiliateNetworkId,
        CancellationToken cancellationToken = default);

    Task AddAsync(
        NetworkCashbackSettings settings,
        CancellationToken cancellationToken = default);
}
