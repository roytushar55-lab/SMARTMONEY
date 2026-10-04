using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class DeletedUserArchiveRepository : IDeletedUserArchiveRepository
{
    private readonly SmartMoneyDbContext _context;

    public DeletedUserArchiveRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(
        DeletedUserArchive archive,
        CancellationToken cancellationToken = default)
    {
        await _context.DeletedUserArchives.AddAsync(archive, cancellationToken);
    }

    public async Task<DeletedUserArchive?> GetByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        return await _context.DeletedUserArchives
            .AsNoTracking()
            .FirstOrDefaultAsync(
                archive => archive.UserId == userId,
                cancellationToken);
    }
}
