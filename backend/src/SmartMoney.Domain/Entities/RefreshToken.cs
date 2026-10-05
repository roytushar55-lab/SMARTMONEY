using SmartMoney.Domain.Common;

using System.Security.Cryptography;
using System.Text;

namespace SmartMoney.Domain.Entities;

public sealed class RefreshToken : BaseEntity
{
    public Guid UserId { get; private set; }

    /// <summary>
    /// SHA-256 of the token the client holds. The raw value is never stored,
    /// so a leaked database or backup cannot be replayed as sessions.
    /// </summary>
    public string Token { get; private set; } = string.Empty;

    public DateTime ExpiresAt { get; private set; }

    public bool IsRevoked { get; private set; }

    public DateTime? RevokedAt { get; private set; }

    public User User { get; private set; } = null!;

    private RefreshToken()
    {
    }

    public RefreshToken(Guid userId, string token, DateTime expiresAt)
    {
        UserId = userId;
        Token = HashToken(token);
        ExpiresAt = expiresAt;
    }

    /// <summary>Hash used to store and look up a raw refresh token.</summary>
    public static string HashToken(string rawToken)
    {
        return Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(rawToken)));
    }

    public bool IsExpired()
    {
        return DateTime.UtcNow >= ExpiresAt;
    }

    public void Revoke()
    {
        IsRevoked = true;
        RevokedAt = DateTime.UtcNow;

        MarkAsUpdated();
    }
}