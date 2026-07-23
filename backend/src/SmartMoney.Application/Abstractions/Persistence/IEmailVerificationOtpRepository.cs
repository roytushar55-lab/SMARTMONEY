using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IEmailVerificationOtpRepository
{
    Task AddAsync(
        EmailVerificationOtp emailVerificationOtp,
        CancellationToken cancellationToken = default);

    Task<EmailVerificationOtp?> GetLatestValidByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default);
}