using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IStoreRepository
{
    Task<IReadOnlyList<Store>> GetActiveAsync (CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Store>> GetActiveByCategorySlugAsync (string categorySlug, CancellationToken cancellationToken = default);
    Task<Store?> GetActiveBySlugAsync (string slug, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Store>> SearchAsync(string searchTerm, CancellationToken cancellationToken = default);

    /// <summary>Admin listing — every store regardless of IsActive, with categories loaded.</summary>
    Task<IReadOnlyList<Store>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>Change-tracked, any status, with categories loaded — for admin edit.</summary>
    Task<Store?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddAsync(Store store, CancellationToken cancellationToken = default);

    Task<bool> NameExistsAsync(
        string name,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    Task<bool> SlugExistsAsync(
        string slug,
        Guid? excludeId,
        CancellationToken cancellationToken = default);
}
