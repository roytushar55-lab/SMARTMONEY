using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class CashbackRateOverrideRepository : ICashbackRateOverrideRepository
{
    private readonly SmartMoneyDbContext _context;

    public CashbackRateOverrideRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task<CashbackRateOverride?> GetActiveAsync(
        Guid affiliateNetworkId,
        Guid storeId,
        Guid? categoryId,
        CancellationToken cancellationToken = default)
    {
        return await _context.CashbackRateOverrides
            .AsNoTracking()
            .FirstOrDefaultAsync(
                @override =>
                    @override.AffiliateNetworkId == affiliateNetworkId
                    && @override.StoreId == storeId
                    && @override.CategoryId == categoryId
                    && @override.IsActive,
                cancellationToken);
    }

    public async Task<IReadOnlyList<CashbackRateOverride>> ListByNetworkIdAsync(
        Guid affiliateNetworkId,
        CancellationToken cancellationToken = default)
    {
        return await _context.CashbackRateOverrides
            .AsNoTracking()
            .Include(@override => @override.Store)
            .Include(@override => @override.Category)
            .Where(@override => @override.AffiliateNetworkId == affiliateNetworkId)
            .OrderByDescending(@override => @override.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<CashbackRateOverride?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return await _context.CashbackRateOverrides
            .FirstOrDefaultAsync(@override => @override.Id == id, cancellationToken);
    }

    public async Task<bool> ExistsAsync(
        Guid affiliateNetworkId,
        Guid storeId,
        Guid? categoryId,
        Guid? excludeId,
        CancellationToken cancellationToken = default)
    {
        return await _context.CashbackRateOverrides
            .AnyAsync(
                @override =>
                    @override.AffiliateNetworkId == affiliateNetworkId
                    && @override.StoreId == storeId
                    && @override.CategoryId == categoryId
                    && (excludeId == null || @override.Id != excludeId),
                cancellationToken);
    }

    public async Task AddAsync(
        CashbackRateOverride @override,
        CancellationToken cancellationToken = default)
    {
        await _context.CashbackRateOverrides.AddAsync(@override, cancellationToken);
    }

    public void Remove(CashbackRateOverride @override)
    {
        _context.CashbackRateOverrides.Remove(@override);
    }
}
