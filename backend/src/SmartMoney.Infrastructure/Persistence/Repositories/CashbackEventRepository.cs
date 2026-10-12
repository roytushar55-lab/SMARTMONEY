using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class CashbackEventRepository : ICashbackEventRepository
{
    private readonly SmartMoneyDbContext _context;

    public CashbackEventRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(
        CashbackEvent cashbackEvent,
        CancellationToken cancellationToken = default)
    {
        await _context.CashbackEvents.AddAsync(cashbackEvent, cancellationToken);
    }

    public async Task<IReadOnlyList<CashbackEvent>> ListByCashbackIdAsync(
        Guid cashbackId,
        CancellationToken cancellationToken = default)
    {
        return await _context.CashbackEvents
            .AsNoTracking()
            .Include(e => e.Actor)
            .Where(e => e.CashbackId == cashbackId)
            .OrderBy(e => e.CreatedAt)
            .ToListAsync(cancellationToken);
    }
}
