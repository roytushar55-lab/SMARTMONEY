using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class UserRepository : IUserRepository
{
    private readonly SmartMoneyDbContext _context;

    public UserRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public Task<bool> ExistsByEmailAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        string normalizedEmail = email.Trim().ToLowerInvariant();

        return _context.Users.AnyAsync(
            user => user.Email == normalizedEmail,
            cancellationToken);
    }

    public Task<bool> ExistsByMobileAsync(
        string mobileNumber,
        CancellationToken cancellationToken = default)
    {
        string normalizedMobile = mobileNumber.Trim();

        return _context.Users.AnyAsync(
            user => user.MobileNumber == normalizedMobile,
            cancellationToken);
    }

    public Task<User?> GetByEmailAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        string normalizedEmail = email.Trim().ToLowerInvariant();

        return _context.Users
            .Include(user => user.Role)
            .SingleOrDefaultAsync(
                user => user.Email == normalizedEmail,
                cancellationToken);
    }

    public Task<User?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return _context.Users
            .Include(user => user.Role)
            .SingleOrDefaultAsync(
                user => user.Id == id,
                cancellationToken);
    }

    public async Task AddAsync(
        User user,
        CancellationToken cancellationToken = default)
    {
        await _context.Users.AddAsync(user, cancellationToken);
    }

    public async Task<IReadOnlyList<User>> ListAsync(
        int page,
        int pageSize,
        string? search = null,
        bool? isActive = null,
        bool? isDeleted = null,
        CancellationToken cancellationToken = default)
    {
        var query = ApplyFilters(
            _context.Users.AsNoTracking().Include(user => user.Role),
            search,
            isActive,
            isDeleted);

        return await query
            .OrderByDescending(user => user.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public Task<int> CountAsync(
        string? search = null,
        bool? isActive = null,
        bool? isDeleted = null,
        CancellationToken cancellationToken = default)
    {
        return ApplyFilters(_context.Users, search, isActive, isDeleted)
            .CountAsync(cancellationToken);
    }

    /// <summary>
    /// Combines the free-text search with the explicit active/inactive
    /// toggle: the status toggle narrows the whole result set first (an AND),
    /// then the search term matches name, email, or a status word within
    /// what's left (an OR) so e.g. the "Active" toggle plus "roy" finds only
    /// active users named/emailed "roy".
    /// </summary>
    private static IQueryable<User> ApplyFilters(
        IQueryable<User> query,
        string? search,
        bool? isActive,
        bool? isDeleted)
    {
        if (isDeleted == true)
        {
            // The "Deleted" filter wins over the active/inactive toggle: a
            // deleted account is neither.
            query = query.Where(user => user.Status == UserStatus.Deleted);
        }
        else if (isActive is not null)
        {
            // "Inactive" means deactivated by an admin; self-deleted
            // accounts have their own "Deleted" status and are excluded.
            query = isActive == true
                ? query.Where(user => user.IsActive)
                : query.Where(user =>
                    !user.IsActive && user.Status != UserStatus.Deleted);
        }

        return ApplySearch(query, search);
    }

    /// <summary>
    /// Matches full name or email substrings, plus a status word
    /// ("active"/"inactive"/"deleted") once the term is long enough to be
    /// unambiguous — short terms like "a" stay name/email-only.
    /// </summary>
    private static IQueryable<User> ApplySearch(IQueryable<User> query, string? search)
    {
        if (string.IsNullOrWhiteSpace(search)) return query;

        string term = search.Trim();

        bool matchActive = false;
        bool matchInactive = false;
        bool matchDeleted = false;
        if (term.Length >= 3)
        {
            string lower = term.ToLowerInvariant();
            if ("active".StartsWith(lower))
            {
                matchActive = true;
            }
            else if ("inactive".Contains(lower) || "disabled".Contains(lower) || "deactivated".Contains(lower))
            {
                matchInactive = true;
            }
            else if ("deleted".StartsWith(lower))
            {
                matchDeleted = true;
            }
        }

        return query.Where(user =>
            EF.Functions.ILike(user.FullName, $"%{term}%") ||
            EF.Functions.ILike(user.Email, $"%{term}%") ||
            (matchActive && user.IsActive) ||
            (matchInactive && !user.IsActive && user.Status != UserStatus.Deleted) ||
            (matchDeleted && user.Status == UserStatus.Deleted));
    }

    /// <summary>
    /// Active users, or users an admin deactivated. Self-deleted accounts
    /// are counted separately by <see cref="CountDeletedAsync"/>.
    /// </summary>
    public Task<int> CountByActiveStatusAsync(
        bool isActive,
        CancellationToken cancellationToken = default)
    {
        return _context.Users.CountAsync(
            user => user.IsActive == isActive
                && user.Status != UserStatus.Deleted,
            cancellationToken);
    }

    public Task<int> CountDeletedAsync(
        CancellationToken cancellationToken = default)
    {
        return _context.Users.CountAsync(
            user => user.Status == UserStatus.Deleted, cancellationToken);
    }

    public Task<int> CountCreatedSinceAsync(
        DateTime since,
        CancellationToken cancellationToken = default)
    {
        return _context.Users.CountAsync(
            user => user.CreatedAt >= since, cancellationToken);
    }
}
