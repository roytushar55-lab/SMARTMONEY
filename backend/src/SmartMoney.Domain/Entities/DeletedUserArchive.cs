using SmartMoney.Domain.Common;

namespace SmartMoney.Domain.Entities;

/// <summary>
/// Restricted, time-limited copy of the personal details a user had when they
/// deleted their account. The live <see cref="User"/> row is anonymized
/// immediately; this copy exists only so a SuperAdmin can handle fraud checks
/// and open disputes, and is erased once <see cref="PurgeAfter"/> passes.
/// </summary>
public sealed class DeletedUserArchive : BaseEntity
{
    public Guid UserId { get; private set; }

    public string FullName { get; private set; } = string.Empty;

    public string Email { get; private set; } = string.Empty;

    public string MobileNumber { get; private set; } = string.Empty;

    public DateTime DeletedAt { get; private set; }

    public DateTime PurgeAfter { get; private set; }

    private DeletedUserArchive()
    {
    }

    public DeletedUserArchive(
        Guid userId,
        string fullName,
        string email,
        string mobileNumber,
        TimeSpan retention)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User is required.", nameof(userId));

        if (retention <= TimeSpan.Zero)
            throw new ArgumentException(
                "Retention must be positive.",
                nameof(retention));

        UserId = userId;
        FullName = fullName;
        Email = email;
        MobileNumber = mobileNumber;
        DeletedAt = DateTime.UtcNow;
        PurgeAfter = DeletedAt.Add(retention);
    }
}
