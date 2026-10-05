namespace SmartMoney.Domain.Common;

/// <summary>
/// Abuse limits shared by the email-verification and password-reset OTP
/// flows. A 6-digit code has only a million values, so guessing must be
/// capped per code, and issuing fresh codes must be throttled so the cap
/// cannot be reset by simply requesting a new one.
/// </summary>
public static class OtpPolicy
{
    /// <summary>Wrong guesses allowed before a code is permanently dead.</summary>
    public const int MaxFailedAttempts = 5;

    /// <summary>Minimum gap between two codes issued to the same user.</summary>
    public static readonly TimeSpan MinResendInterval = TimeSpan.FromSeconds(60);

    /// <summary>Most codes that may be issued to one user in any hour.</summary>
    public const int MaxIssuedPerHour = 5;

    /// <summary>
    /// True when another code may be issued, given when the user's recent
    /// codes were created (all within the last hour).
    /// </summary>
    public static bool CanIssue(IReadOnlyCollection<DateTime> recentCreatedAtUtc, DateTime nowUtc)
    {
        if (recentCreatedAtUtc.Count >= MaxIssuedPerHour)
        {
            return false;
        }

        foreach (DateTime createdAt in recentCreatedAtUtc)
        {
            if (nowUtc - createdAt < MinResendInterval)
            {
                return false;
            }
        }

        return true;
    }
}
