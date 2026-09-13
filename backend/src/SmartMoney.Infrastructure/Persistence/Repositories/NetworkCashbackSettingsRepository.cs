using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class NetworkCashbackSettingsRepository : INetworkCashbackSettingsRepository
{
    private readonly SmartMoneyDbContext _context;

    public NetworkCashbackSettingsRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task<NetworkCashbackSettings?> GetByNetworkIdAsync(
        Guid affiliateNetworkId,
        CancellationToken cancellationToken = default)
    {
        return await _context.NetworkCashbackSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(
                settings => settings.AffiliateNetworkId == affiliateNetworkId,
                cancellationToken);
    }

    public async Task<NetworkCashbackSettings?> GetTrackedByNetworkIdAsync(
        Guid affiliateNetworkId,
        CancellationToken cancellationToken = default)
    {
        return await _context.NetworkCashbackSettings
            .FirstOrDefaultAsync(
                settings => settings.AffiliateNetworkId == affiliateNetworkId,
                cancellationToken);
    }

    public async Task AddAsync(
        NetworkCashbackSettings settings,
        CancellationToken cancellationToken = default)
    {
        await _context.NetworkCashbackSettings.AddAsync(settings, cancellationToken);
    }
}
