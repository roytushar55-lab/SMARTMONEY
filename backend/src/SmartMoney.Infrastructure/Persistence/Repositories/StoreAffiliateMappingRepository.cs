using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class StoreAffiliateMappingRepository : IStoreAffiliateMappingRepository
{
    private readonly SmartMoneyDbContext _dbContext;

    public StoreAffiliateMappingRepository(SmartMoneyDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<StoreAffiliateMapping?> GetActiveByStoreIdAsync(Guid storeId, CancellationToken cancellationToken = default)
    {
        return await _dbContext.StoreAffiliateMappings
            .AsNoTracking()
            .Include(mapping => mapping.Store)
            .Include(mapping => mapping.AffiliateNetwork)
            .FirstOrDefaultAsync(mapping =>
                mapping.StoreId == storeId &&
                mapping.IsActive &&
                mapping.Store.IsActive &&
                mapping.AffiliateNetwork.IsActive,
                cancellationToken);
    }

    public async Task<IReadOnlyList<StoreAffiliateMapping>> GetAllAsync(
        Guid? storeId,
        CancellationToken cancellationToken = default)
    {
        var query = _dbContext.StoreAffiliateMappings
            .AsNoTracking()
            .Include(mapping => mapping.Store)
            .Include(mapping => mapping.AffiliateNetwork)
            .AsQueryable();

        if (storeId is Guid filterStoreId)
        {
            query = query.Where(mapping => mapping.StoreId == filterStoreId);
        }

        return await query
            .OrderBy(mapping => mapping.Store.Name)
            .ThenBy(mapping => mapping.AffiliateNetwork.Name)
            .ToListAsync(cancellationToken);
    }

    public async Task<StoreAffiliateMapping?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return await _dbContext.StoreAffiliateMappings
            .Include(mapping => mapping.Store)
            .Include(mapping => mapping.AffiliateNetwork)
            .FirstOrDefaultAsync(mapping => mapping.Id == id, cancellationToken);
    }

    public async Task AddAsync(
        StoreAffiliateMapping mapping,
        CancellationToken cancellationToken = default)
    {
        await _dbContext.StoreAffiliateMappings.AddAsync(mapping, cancellationToken);
    }

    public async Task<bool> StoreNetworkPairExistsAsync(
        Guid storeId,
        Guid affiliateNetworkId,
        Guid? excludeId,
        CancellationToken cancellationToken = default)
    {
        return await _dbContext.StoreAffiliateMappings
            .AsNoTracking()
            .AnyAsync(
                mapping => mapping.StoreId == storeId &&
                    mapping.AffiliateNetworkId == affiliateNetworkId &&
                    (excludeId == null || mapping.Id != excludeId),
                cancellationToken);
    }

    public async Task<bool> ExternalMerchantIdExistsAsync(
        Guid affiliateNetworkId,
        string externalMerchantId,
        Guid? excludeId,
        CancellationToken cancellationToken = default)
    {
        return await _dbContext.StoreAffiliateMappings
            .AsNoTracking()
            .AnyAsync(
                mapping => mapping.AffiliateNetworkId == affiliateNetworkId &&
                    mapping.ExternalMerchantId == externalMerchantId &&
                    (excludeId == null || mapping.Id != excludeId),
                cancellationToken);
    }
}
