using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IDeletedUserArchiveRepository
{
    Task AddAsync(
        DeletedUserArchive archive,
        CancellationToken cancellationToken = default);

    /// <summary>Read-only. Null once the archive has been purged.</summary>
    Task<DeletedUserArchive?> GetByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default);
}
