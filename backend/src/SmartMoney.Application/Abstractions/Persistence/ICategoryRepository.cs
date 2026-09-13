using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface ICategoryRepository
{
    Task<IReadOnlyList<Category>> GetActiveAsync(
        CancellationToken cancellationToken = default);

    /// <summary>Admin listing — every category regardless of IsActive.</summary>
    Task<IReadOnlyList<Category>> GetAllAsync(
        CancellationToken cancellationToken = default);

    /// <summary>Change-tracked, any status — for admin edit.</summary>
    Task<Category?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    Task AddAsync(Category category, CancellationToken cancellationToken = default);

    Task<bool> NameExistsAsync(
        string name,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    Task<bool> SlugExistsAsync(
        string slug,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    /// <summary>Tracked. Categories whose DisplayOrder falls in [minOrder, maxOrder], for shifting.</summary>
    Task<IReadOnlyList<Category>> GetTrackedByDisplayOrderRangeAsync(
        int minOrder,
        int maxOrder,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    /// <summary>True only if every id in <paramref name="ids"/> exists.</summary>
    Task<bool> AllExistAsync(
        IEnumerable<Guid> ids,
        CancellationToken cancellationToken = default);
}
