using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class EmailVerificationOtpRepository
    : IEmailVerificationOtpRepository
{
    private readonly SmartMoneyDbContext _context;

    public EmailVerificationOtpRepository(
        SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(
        EmailVerificationOtp emailVerificationOtp,
        CancellationToken cancellationToken = default)
    {
        await _context.EmailVerificationOtps.AddAsync(
            emailVerificationOtp,
            cancellationToken);
    }

    public Task<EmailVerificationOtp?> GetLatestValidByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        DateTime currentTime = DateTime.UtcNow;

        return _context.EmailVerificationOtps
            .Where(otp =>
                otp.UserId == userId &&
                !otp.IsUsed &&
                otp.ExpiresAt > currentTime)
            .OrderByDescending(otp => otp.ExpiresAt)
            .FirstOrDefaultAsync(cancellationToken);
    }
}