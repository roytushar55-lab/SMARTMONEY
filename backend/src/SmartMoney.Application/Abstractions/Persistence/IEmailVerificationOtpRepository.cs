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

    /// <summary>
    /// Creation times of the codes issued to this user since <paramref name="sinceUtc"/>,
    /// used to throttle how often new codes can be requested.
    /// </summary>
    Task<IReadOnlyList<DateTime>> ListCreatedAtSinceAsync(
        Guid userId,
        DateTime sinceUtc,
        CancellationToken cancellationToken = default);
}