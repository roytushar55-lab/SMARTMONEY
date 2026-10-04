using SmartMoney.Domain.Common;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Domain.Entities;

public class User : BaseEntity
{
    public string FullName { get; private set; } = string.Empty;

    public string Email { get; private set; } = string.Empty;

    public string MobileNumber { get; private set; } = string.Empty;

    /// <summary>
    /// Null for accounts created via an external provider (Google) that have
    /// never set a password.
    /// </summary>
    public string? PasswordHash { get; private set; }

    /// <summary>
    /// Google's stable per-account subject id, set once a Google sign-in has
    /// been linked to this account. Null for accounts that have never used
    /// Google sign-in.
    /// </summary>
    public string? GoogleId { get; private set; }

    public string? ProfileImageUrl { get; private set; }

    public UserStatus Status { get; private set; } = UserStatus.Pending;

    public Guid RoleId { get; private set; }

    public Role? Role { get; private set; }

    public bool IsEmailVerified { get; private set; }

    public bool IsMobileVerified { get; private set; }

    public bool IsActive { get; private set; } = true;

    /// <summary>
    /// When the user ticked the age (18+) and Terms/Privacy checkboxes at
    /// signup. Null for accounts created before consent was captured, and
    /// for Google-created accounts.
    /// </summary>
    public DateTime? ConsentAcceptedAt { get; private set; }

    /// <summary>The Terms/Privacy version the user was shown and accepted.</summary>
    public string? ConsentVersion { get; private set; }

    public string? ConsentIpAddress { get; private set; }

    private User()
    {
    }

    public User(
        string fullName,
        string email,
        string mobileNumber,
        string passwordHash,
        Guid roleId)
    {
        if (string.IsNullOrWhiteSpace(fullName))
            throw new ArgumentException(
                "Full name is required.",
                nameof(fullName));

        if (string.IsNullOrWhiteSpace(email))
            throw new ArgumentException(
                "Email is required.",
                nameof(email));

        if (string.IsNullOrWhiteSpace(mobileNumber))
            throw new ArgumentException(
                "Mobile number is required.",
                nameof(mobileNumber));

        if (string.IsNullOrWhiteSpace(passwordHash))
            throw new ArgumentException(
                "Password hash is required.",
                nameof(passwordHash));

        if (roleId == Guid.Empty)
            throw new ArgumentException(
                "Role is required.",
                nameof(roleId));

        FullName = fullName.Trim();
        Email = email.Trim().ToLowerInvariant();
        MobileNumber = mobileNumber.Trim();
        PasswordHash = passwordHash;
        RoleId = roleId;
    }

    public void RecordConsent(string version, string? ipAddress)
    {
        if (string.IsNullOrWhiteSpace(version))
            throw new ArgumentException(
                "Consent version is required.",
                nameof(version));

        ConsentAcceptedAt = DateTime.UtcNow;
        ConsentVersion = version.Trim();
        ConsentIpAddress = string.IsNullOrWhiteSpace(ipAddress)
            ? null
            : ipAddress.Trim();
        MarkAsUpdated();
    }

    /// <summary>
    /// Final step of user-initiated account deletion: strips every personal
    /// field (the unique email/mobile are replaced by unreachable
    /// placeholders), removes the ability to sign in, and marks the account
    /// deleted. Ledger rows that reference this user are intentionally kept.
    /// </summary>
    public void AnonymizeForDeletion()
    {
        string suffix = Id.ToString("N");

        FullName = "Deleted user";
        Email = $"deleted-{suffix}@deleted.invalid";
        MobileNumber = $"del-{suffix[..12]}";
        PasswordHash = null;
        GoogleId = null;
        ProfileImageUrl = null;
        IsActive = false;
        Status = UserStatus.Deleted;
        MarkAsUpdated();
    }

    public void VerifyEmail()
    {
        IsEmailVerified = true;
        MarkAsUpdated();
    }

    public void VerifyMobile()
    {
        IsMobileVerified = true;
        MarkAsUpdated();
    }

    public void Deactivate()
    {
        IsActive = false;
        MarkAsUpdated();
    }

    public void Activate()
    {
        IsActive = true;
        MarkAsUpdated();
    }

    public void ActivateAccount()
    {
        Status = UserStatus.Active;
        MarkAsUpdated();
    }

    public void SuspendAccount()
    {
        Status = UserStatus.Suspended;
        MarkAsUpdated();
    }

    public void BlockAccount()
    {
        Status = UserStatus.Blocked;
        MarkAsUpdated();
    }

    public void DeleteAccount()
    {
        Status = UserStatus.Deleted;
        MarkAsUpdated();
    }

    public void ChangeRole(Guid roleId)
    {
        RoleId = roleId;
        MarkAsUpdated();
    }

    public void UpdateFullName(string fullName)
    {
        if (string.IsNullOrWhiteSpace(fullName))
            throw new ArgumentException(
                "Full name is required.",
                nameof(fullName));

        FullName = fullName.Trim();
        MarkAsUpdated();
    }

    public void ChangePasswordHash(string passwordHash)
    {
        if (string.IsNullOrWhiteSpace(passwordHash))
            throw new ArgumentException(
                "Password hash is required.",
                nameof(passwordHash));

        PasswordHash = passwordHash;
        MarkAsUpdated();
    }

    public void UpdateProfileImageUrl(string profileImageUrl)
    {
        ProfileImageUrl = string.IsNullOrWhiteSpace(profileImageUrl)
            ? null
            : profileImageUrl.Trim();

        MarkAsUpdated();
    }
}
