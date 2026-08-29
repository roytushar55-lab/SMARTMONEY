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
}
