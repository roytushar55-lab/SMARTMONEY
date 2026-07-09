using SmartMoney.Domain.Common;

namespace SmartMoney.Domain.Entities;

public sealed class RefreshToken : BaseEntity
{
    public Guid UserId { get; private set; }

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
        Token = token;
        ExpiresAt = expiresAt;
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