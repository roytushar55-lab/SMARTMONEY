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

    /// <summary>
    /// Creates a new account for a Google identity that has no matching
    /// existing user. There is no password — <see cref="PasswordHash"/>
    /// stays null — and the account is activated immediately since Google
    /// has already verified the email address, skipping the normal
    /// register-then-verify-OTP flow.
    /// </summary>
    public static User CreateFromGoogle(
        string fullName,
        string email,
        string googleId,
        Role role)
    {
        if (string.IsNullOrWhiteSpace(fullName))
            throw new ArgumentException(
                "Full name is required.",
                nameof(fullName));

        if (string.IsNullOrWhiteSpace(email))
            throw new ArgumentException(
                "Email is required.",
                nameof(email));

        if (string.IsNullOrWhiteSpace(googleId))
            throw new ArgumentException(
                "Google id is required.",
                nameof(googleId));

        ArgumentNullException.ThrowIfNull(role);

        return new User
        {
            FullName = fullName.Trim(),
            Email = email.Trim().ToLowerInvariant(),
            MobileNumber = string.Empty,
            PasswordHash = null,
            GoogleId = googleId,
            RoleId = role.Id,
            Role = role,
            Status = UserStatus.Active,
            IsEmailVerified = true
        };
    }

    /// <summary>
    /// Links a Google identity to an existing (typically password-based)
    /// account whose email matched a Google sign-in attempt. Does not touch
    /// the existing password, so the account keeps working with either
    /// method afterwards.
    /// </summary>
    public void LinkGoogleAccount(string googleId)
    {
        if (string.IsNullOrWhiteSpace(googleId))
            throw new ArgumentException(
                "Google id is required.",
                nameof(googleId));

        GoogleId = googleId;
        MarkAsUpdated();
    }
}
