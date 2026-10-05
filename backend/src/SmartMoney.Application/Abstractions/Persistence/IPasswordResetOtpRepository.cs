using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IPasswordResetOtpRepository
{
    Task AddAsync(
        PasswordResetOtp passwordResetOtp,
        CancellationToken cancellationToken = default);

    Task<PasswordResetOtp?> GetLatestValidByUserIdAsync(
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
