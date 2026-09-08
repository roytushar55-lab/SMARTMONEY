using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IStoreAffiliateMappingRepository
{
    Task<StoreAffiliateMapping?> GetActiveByStoreIdAsync(Guid storeId, CancellationToken cancellationToken = default);

    /// <summary>Admin listing — every mapping regardless of IsActive, optionally filtered to one store.</summary>
    Task<IReadOnlyList<StoreAffiliateMapping>> GetAllAsync(
        Guid? storeId,
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked — for admin edit.</summary>
    Task<StoreAffiliateMapping?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddAsync(StoreAffiliateMapping mapping, CancellationToken cancellationToken = default);

    /// <summary>Backs the unique (StoreId, AffiliateNetworkId) constraint.</summary>
    Task<bool> StoreNetworkPairExistsAsync(
        Guid storeId,
        Guid affiliateNetworkId,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    /// <summary>Backs the unique (AffiliateNetworkId, ExternalMerchantId) constraint.</summary>
    Task<bool> ExternalMerchantIdExistsAsync(
        Guid affiliateNetworkId,
        string externalMerchantId,
        Guid? excludeId,
        CancellationToken cancellationToken = default);
}
