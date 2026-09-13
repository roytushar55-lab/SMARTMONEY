using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IAffiliateNetworkRepository
{
    /// <summary>
    /// Resolves a network by its code regardless of <c>IsActive</c>:
    /// inbound conversions must not be dropped because a network is paused.
    /// </summary>
    Task<AffiliateNetwork?> GetByCodeAsync(string code, CancellationToken cancellationToken = default);

    /// <summary>Admin listing — every network regardless of IsActive.</summary>
    Task<IReadOnlyList<AffiliateNetwork>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>Change-tracked — for admin edit.</summary>
    Task<AffiliateNetwork?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddAsync(AffiliateNetwork network, CancellationToken cancellationToken = default);

    Task<bool> NameExistsAsync(
        string name,
        Guid? excludeId,
        CancellationToken cancellationToken = default);

    Task<bool> CodeExistsAsync(
        string code,
        Guid? excludeId,
        CancellationToken cancellationToken = default);
}
