using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class CashbackRepository : ICashbackRepository
{
    private readonly SmartMoneyDbContext _context;

    public CashbackRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(Cashback cashback, CancellationToken cancellationToken = default)
    {
        await _context.Cashbacks.AddAsync(cashback, cancellationToken);
    }

    public async Task<Cashback?> GetByConversionIdAsync(
        Guid affiliateConversionId,
        CancellationToken cancellationToken = default)
    {
        return await _context.Cashbacks
            .FirstOrDefaultAsync(
                cashback => cashback.AffiliateConversionId == affiliateConversionId,
                cancellationToken);
    }

    public async Task<Cashback?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return await _context.Cashbacks
            .FirstOrDefaultAsync(cashback => cashback.Id == id, cancellationToken);
    }

    public async Task<IReadOnlyList<Cashback>> ListByStatusAsync(
        CashbackStatus? status,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        return await QueryByStatus(status)
            .AsNoTracking()
            .Include(cashback => cashback.User)
            .Include(cashback => cashback.AffiliateConversion)
                .ThenInclude(conversion => conversion.AffiliateClick!)
                    .ThenInclude(click => click.Store)
            .OrderByDescending(cashback => cashback.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> CountByStatusAsync(
        CashbackStatus? status,
        CancellationToken cancellationToken = default)
    {
        return await QueryByStatus(status).CountAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Cashback>> ListByUserIdAsync(
        Guid userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        return await _context.Cashbacks
            .AsNoTracking()
            .Where(cashback => cashback.UserId == userId)
            .Include(cashback => cashback.AffiliateConversion)
                .ThenInclude(conversion => conversion.AffiliateClick!)
                    .ThenInclude(click => click.Store)
            .OrderByDescending(cashback => cashback.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> CountByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        return await _context.Cashbacks
            .CountAsync(cashback => cashback.UserId == userId, cancellationToken);
    }

    public async Task<IReadOnlyDictionary<CashbackStatus, (int Count, decimal Amount)>> GetStatusSummaryByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var rows = await _context.Cashbacks
            .Where(cashback => cashback.UserId == userId)
            .GroupBy(cashback => cashback.Status)
            .Select(group => new
            {
                Status = group.Key,
                Count = group.Count(),
                Amount = group.Sum(cashback => cashback.CashbackAmount)
            })
            .ToListAsync(cancellationToken);

        return rows.ToDictionary(row => row.Status, row => (row.Count, row.Amount));
    }

    private IQueryable<Cashback> QueryByStatus(CashbackStatus? status)
    {
        return status is CashbackStatus filter
            ? _context.Cashbacks.Where(cashback => cashback.Status == filter)
            : _context.Cashbacks;
    }
}
