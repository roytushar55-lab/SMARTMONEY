using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class AffiliateNetworkRepository : IAffiliateNetworkRepository
{
    private readonly SmartMoneyDbContext _dbContext;

    public AffiliateNetworkRepository(SmartMoneyDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<AffiliateNetwork?> GetByCodeAsync(string code, CancellationToken cancellationToken = default)
    {
        return await _dbContext.AffiliateNetworks
            .AsNoTracking()
            .FirstOrDefaultAsync(
                network => network.Code == code,
                cancellationToken);
    }

    public async Task<IReadOnlyList<AffiliateNetwork>> GetAllAsync(
        CancellationToken cancellationToken = default)
    {
        return await _dbContext.AffiliateNetworks
            .AsNoTracking()
            .OrderBy(network => network.Name)
            .ToListAsync(cancellationToken);
    }

    public async Task<AffiliateNetwork?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return await _dbContext.AffiliateNetworks
            .FirstOrDefaultAsync(network => network.Id == id, cancellationToken);
    }

    public async Task AddAsync(
        AffiliateNetwork network,
        CancellationToken cancellationToken = default)
    {
        await _dbContext.AffiliateNetworks.AddAsync(network, cancellationToken);
    }

    public async Task<bool> NameExistsAsync(
        string name,
        Guid? excludeId,
        CancellationToken cancellationToken = default)
    {
        return await _dbContext.AffiliateNetworks
            .AsNoTracking()
            .AnyAsync(
                network => network.Name == name &&
                    (excludeId == null || network.Id != excludeId),
                cancellationToken);
    }

    public async Task<bool> CodeExistsAsync(
        string code,
        Guid? excludeId,
        CancellationToken cancellationToken = default)
    {
        return await _dbContext.AffiliateNetworks
            .AsNoTracking()
            .AnyAsync(
                network => network.Code == code &&
                    (excludeId == null || network.Id != excludeId),
                cancellationToken);
    }
}
