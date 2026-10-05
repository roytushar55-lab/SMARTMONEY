using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Common;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class PasswordResetOtpRepository : IPasswordResetOtpRepository
{
    private readonly SmartMoneyDbContext _context;

    public PasswordResetOtpRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(
        PasswordResetOtp passwordResetOtp,
        CancellationToken cancellationToken = default)
    {
        await _context.PasswordResetOtps.AddAsync(passwordResetOtp, cancellationToken);
    }

    public Task<PasswordResetOtp?> GetLatestValidByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        DateTime currentTime = DateTime.UtcNow;

        return _context.PasswordResetOtps
            .Where(otp =>
                otp.UserId == userId &&
                !otp.IsUsed &&
                otp.ExpiresAt > currentTime &&
                otp.FailedAttempts < OtpPolicy.MaxFailedAttempts)
            .OrderByDescending(otp => otp.ExpiresAt)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<DateTime>> ListCreatedAtSinceAsync(
        Guid userId,
        DateTime sinceUtc,
        CancellationToken cancellationToken = default)
    {
        return await _context.PasswordResetOtps
            .AsNoTracking()
            .Where(otp => otp.UserId == userId && otp.CreatedAt >= sinceUtc)
            .Select(otp => otp.CreatedAt)
            .ToListAsync(cancellationToken);
    }
}
