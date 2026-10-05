using Moq;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Identity.RefreshToken;
using SmartMoney.Domain.Entities;
using RefreshTokenEntity = SmartMoney.Domain.Entities.RefreshToken;

namespace SmartMoney.Application.Tests.Identity;

public sealed class RefreshTokenReuseTests
{
    private readonly Mock<IRefreshTokenRepository> _tokens = new();
    private readonly Mock<IJwtTokenGenerator> _jwt = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private RefreshTokenCommandHandler CreateHandler()
    {
        return new RefreshTokenCommandHandler(
            _tokens.Object,
            _jwt.Object,
            _unitOfWork.Object,
            new RefreshTokenValidator());
    }

    private RefreshTokenEntity RevokedToken(TimeSpan revokedAgo)
    {
        var user = new User("Test User", "t@example.com", "9876543210", "hash", Guid.NewGuid());
        var token = new RefreshTokenEntity(user.Id, "raw", DateTime.UtcNow.AddDays(7));
        token.Revoke();

        typeof(RefreshTokenEntity)
            .GetProperty(nameof(RefreshTokenEntity.RevokedAt))!
            .SetValue(token, DateTime.UtcNow - revokedAgo);

        _tokens.Setup(t => t.GetByTokenAsync("raw", It.IsAny<CancellationToken>()))
            .ReturnsAsync(token);

        return token;
    }

    [Fact]
    public async Task ReusingAnOldRevokedToken_RevokesEverySessionOfThatUser()
    {
        var token = RevokedToken(TimeSpan.FromMinutes(5));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new RefreshTokenCommand("raw"),
                CancellationToken.None));

        _tokens.Verify(
            t => t.RevokeAllForUserAsync(token.UserId, It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task ReusingATokenRevokedSecondsAgo_IsRejectedButNotTreatedAsTheft()
    {
        RevokedToken(TimeSpan.FromSeconds(2));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new RefreshTokenCommand("raw"),
                CancellationToken.None));

        _tokens.Verify(
            t => t.RevokeAllForUserAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
