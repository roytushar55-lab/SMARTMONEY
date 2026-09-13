using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
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

    public Task<User?> GetByGoogleIdAsync(
        string googleId,
        CancellationToken cancellationToken = default)
    {
        return _context.Users
            .Include(user => user.Role)
            .SingleOrDefaultAsync(
                user => user.GoogleId == googleId,
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
        CancellationToken cancellationToken = default)
    {
        var query = ApplyFilters(
            _context.Users.AsNoTracking().Include(user => user.Role),
            search,
            isActive);

        return await query
            .OrderByDescending(user => user.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public Task<int> CountAsync(
        string? search = null,
        bool? isActive = null,
        CancellationToken cancellationToken = default)
    {
        return ApplyFilters(_context.Users, search, isActive).CountAsync(cancellationToken);
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
        bool? isActive)
    {
        if (isActive is not null)
        {
            query = query.Where(user => user.IsActive == isActive);
        }

        return ApplySearch(query, search);
    }

    /// <summary>
    /// Matches full name or email substrings, plus a status word
    /// ("active"/"inactive"/"disabled") once the term is long enough to be
    /// unambiguous — short terms like "a" stay name/email-only.
    /// </summary>
    private static IQueryable<User> ApplySearch(IQueryable<User> query, string? search)
    {
        if (string.IsNullOrWhiteSpace(search)) return query;

        string term = search.Trim();

        bool? statusFilter = null;
        if (term.Length >= 3)
        {
            string lower = term.ToLowerInvariant();
            if ("inactive".Contains(lower) || "disabled".Contains(lower) || "deactivated".Contains(lower))
            {
                statusFilter = false;
            }
            else if ("active".StartsWith(lower))
            {
                statusFilter = true;
            }
        }

        return query.Where(user =>
            EF.Functions.ILike(user.FullName, $"%{term}%") ||
            EF.Functions.ILike(user.Email, $"%{term}%") ||
            (statusFilter != null && user.IsActive == statusFilter));
    }

    public Task<int> CountByActiveStatusAsync(
        bool isActive,
        CancellationToken cancellationToken = default)
    {
        return _context.Users.CountAsync(
            user => user.IsActive == isActive, cancellationToken);
    }

    public Task<int> CountCreatedSinceAsync(
        DateTime since,
        CancellationToken cancellationToken = default)
    {
        return _context.Users.CountAsync(
            user => user.CreatedAt >= since, cancellationToken);
    }
}
