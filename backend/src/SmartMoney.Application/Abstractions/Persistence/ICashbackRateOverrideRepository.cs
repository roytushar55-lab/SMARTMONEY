using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface ICashbackRateOverrideRepository
{
    /// <summary>
    /// Resolution lookup: the most specific active override for a network,
    /// store and (optionally) category. Read-only.
    /// </summary>
    Task<CashbackRateOverride?> GetActiveAsync(
        Guid affiliateNetworkId,
        Guid storeId,
        Guid? categoryId,
        CancellationToken cancellationToken = default);

    /// <summary>Admin listing for one network, with Store/Category loaded. Newest first.</summary>
    Task<IReadOnlyList<CashbackRateOverride>> ListByNetworkIdAsync(
        Guid affiliateNetworkId,
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked, no includes — for admin edit/delete.</summary>
    Task<CashbackRateOverride?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    Task<bool> ExistsAsync(
        Guid affiliateNetworkId,
        Guid storeId,
        Guid? categoryId,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    Task AddAsync(CashbackRateOverride @override, CancellationToken cancellationToken = default);

    void Remove(CashbackRateOverride @override);
}
