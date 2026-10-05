using SmartMoney.Domain.Common;

namespace SmartMoney.Domain.Entities;

public sealed class EmailVerificationOtp : BaseEntity
{
    public Guid UserId { get; private set; }

    public string CodeHash { get; private set; } = string.Empty;

    public DateTime ExpiresAt { get; private set; }

    public bool IsUsed { get; private set; }

    public DateTime? UsedAt { get; private set; }

    /// <summary>Wrong guesses so far; the code dies at <see cref="OtpPolicy.MaxFailedAttempts"/>.</summary>
    public int FailedAttempts { get; private set; }

    public User User { get; private set; } = null!;

    private EmailVerificationOtp()
    {
    }

    public EmailVerificationOtp(
        Guid userId,
        string codeHash,
        DateTime expiresAt)
    {
        if (userId == Guid.Empty)
        {
            throw new ArgumentException(
                "User ID is required.",
                nameof(userId));
        }

        if (string.IsNullOrWhiteSpace(codeHash))
        {
            throw new ArgumentException(
                "OTP code hash is required.",
                nameof(codeHash));
        }

        if (expiresAt <= DateTime.UtcNow)
        {
            throw new ArgumentException(
                "OTP expiration must be in the future.",
                nameof(expiresAt));
        }

        UserId = userId;
        CodeHash = codeHash;
        ExpiresAt = expiresAt;
    }

    public bool IsLocked => FailedAttempts >= OtpPolicy.MaxFailedAttempts;

    public void RegisterFailedAttempt()
    {
        FailedAttempts++;
        MarkAsUpdated();
    }

    public bool IsExpired()
    {
        return DateTime.UtcNow >= ExpiresAt;
    }

    public void MarkAsUsed()
    {
        if (IsUsed)
        {
            return;
        }

        IsUsed = true;
        UsedAt = DateTime.UtcNow;

        MarkAsUpdated();
    }
}