using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IOfferRepository
{
    Task<IReadOnlyList<Offer>> GetActiveAsync(CancellationToken cancellationToken = default);
    Task<Offer?> GetActiveBySlugAsync(string slug, CancellationToken cancellationToken = default);
    Task<Offer?> GetActiveByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Offer>> SearchAsync(string searchTerm, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Offer>> GetActiveByStoreSlugAsync(string storeSlug,CancellationToken cancellationToken = default);

    /// <summary>Admin listing — every offer regardless of IsActive/date window, optionally filtered to one store.</summary>
    Task<IReadOnlyList<Offer>> GetAllAsync(
        Guid? storeId,
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked, any status — for admin edit.</summary>
    Task<Offer?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddAsync(Offer offer, CancellationToken cancellationToken = default);

    Task<bool> SlugExistsAsync(
        string slug,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    /// <summary>Tracked, global (not store-scoped). Offers whose Priority falls in [minOrder, maxOrder], for shifting.</summary>
    Task<IReadOnlyList<Offer>> GetTrackedByPriorityRangeAsync(
        int minOrder,
        int maxOrder,
        Guid? excludeId,
        CancellationToken cancellationToken = default);
}
