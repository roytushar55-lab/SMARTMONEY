using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Abstractions.Persistence;

public interface IUserRepository
{
    Task<bool> ExistsByEmailAsync(
        string email,
        CancellationToken cancellationToken = default);

    Task<bool> ExistsByMobileAsync(
        string mobileNumber,
        CancellationToken cancellationToken = default);

    Task<User?> GetByEmailAsync(
        string email,
        CancellationToken cancellationToken = default);

    Task<User?> GetByGoogleIdAsync(
        string googleId,
        CancellationToken cancellationToken = default);

    Task<User?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    Task AddAsync(
        User user,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Admin user listing. Read-only. Newest first. When <paramref name="search"/>
    /// is set, matches users whose full name or email contains it, or whose
    /// active/inactive status it names. When <paramref name="isActive"/> is
    /// set, narrows to only that status first (independent of the toggle
    /// implied by <paramref name="search"/>).
    /// </summary>
    Task<IReadOnlyList<User>> ListAsync(
        int page,
        int pageSize,
        string? search = null,
        bool? isActive = null,
        CancellationToken cancellationToken = default);

    Task<int> CountAsync(
        string? search = null,
        bool? isActive = null,
        CancellationToken cancellationToken = default);

    Task<int> CountByActiveStatusAsync(
        bool isActive,
        CancellationToken cancellationToken = default);

    Task<int> CountCreatedSinceAsync(
        DateTime since,
        CancellationToken cancellationToken = default);
}
