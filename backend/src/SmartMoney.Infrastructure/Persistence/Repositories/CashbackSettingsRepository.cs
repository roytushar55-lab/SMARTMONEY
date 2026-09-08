using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class CashbackSettingsRepository : ICashbackSettingsRepository
{
    private readonly SmartMoneyDbContext _context;

    public CashbackSettingsRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task<CashbackSettings?> GetAsync(CancellationToken cancellationToken = default)
    {
        return await _context.CashbackSettings
            .AsNoTracking()
            .OrderBy(settings => settings.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<CashbackSettings?> GetTrackedAsync(CancellationToken cancellationToken = default)
    {
        return await _context.CashbackSettings
            .OrderBy(settings => settings.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }
}
