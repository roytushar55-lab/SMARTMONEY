using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks.ListCashbacks;
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
        // The conversion rides along so decisions can record the network
        // status they were made against.
        return await _context.Cashbacks
            .Include(cashback => cashback.AffiliateConversion)
            .FirstOrDefaultAsync(cashback => cashback.Id == id, cancellationToken);
    }

    public async Task<IReadOnlyList<Cashback>> ListAsync(
        CashbackListFilter filter,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        return await Filtered(filter)
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

    public async Task<int> CountAsync(
        CashbackListFilter filter,
        CancellationToken cancellationToken = default)
    {
        return await Filtered(filter).CountAsync(cancellationToken);
    }

    public async Task<decimal> SumAmountAsync(
        Expression<Func<Cashback, bool>> predicate,
        CancellationToken cancellationToken = default)
    {
        // Nullable sum so an empty set gives zero instead of an error.
        return await _context.Cashbacks
            .Where(predicate)
            .SumAsync(cashback => (decimal?)cashback.CashbackAmount, cancellationToken) ?? 0m;
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

    public async Task<IReadOnlyList<Cashback>> ListUnconfirmedByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        return await _context.Cashbacks
            .Where(cashback =>
                cashback.UserId == userId
                && cashback.ConfirmedDate == null
                && (cashback.Status == CashbackStatus.Pending
                    || cashback.Status == CashbackStatus.AwaitingAdminReview))
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

    private IQueryable<Cashback> Filtered(CashbackListFilter filter)
    {
        IQueryable<Cashback> query = _context.Cashbacks;

        foreach (var predicate in filter.Predicates())
        {
            query = query.Where(predicate);
        }

        return query;
    }
}
