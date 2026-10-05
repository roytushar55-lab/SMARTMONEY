using System.Security.Cryptography;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.RefreshToken;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using RefreshTokenEntity = SmartMoney.Domain.Entities.RefreshToken;

namespace SmartMoney.Application.Features.Identity.RefreshToken;

public sealed class RefreshTokenCommandHandler
    : ICommandHandler<RefreshTokenCommand, RefreshTokenResponse>
{
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IJwtTokenGenerator _jwtTokenGenerator;
    private readonly IUnitOfWork _unitOfWork;
    private readonly RefreshTokenValidator _validator;

    public RefreshTokenCommandHandler(
        IRefreshTokenRepository refreshTokenRepository,
        IJwtTokenGenerator jwtTokenGenerator,
        IUnitOfWork unitOfWork,
        RefreshTokenValidator validator)
    {
        _refreshTokenRepository = refreshTokenRepository;
        _jwtTokenGenerator = jwtTokenGenerator;
        _unitOfWork = unitOfWork;
        _validator = validator;
    }

    public async Task<RefreshTokenResponse> HandleAsync(
        RefreshTokenCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        IReadOnlyCollection<string> validationErrors =
            _validator.Validate(command);

        if (validationErrors.Count > 0)
        {
            throw new ArgumentException(
                string.Join(" ", validationErrors));
        }

        RefreshTokenEntity? existingRefreshToken =
            await _refreshTokenRepository.GetByTokenAsync(
                command.RefreshToken.Trim(),
                cancellationToken);

        // A refresh token is single-use. Seeing a revoked one again means it
        // was copied (or replayed): burn every session of that user so the
        // thief and the owner both have to sign in again. A short grace
        // window covers an honest client that fired two refreshes at once.
        if (existingRefreshToken is { IsRevoked: true } reused &&
            reused.RevokedAt is { } revokedAt &&
            DateTime.UtcNow - revokedAt > TimeSpan.FromSeconds(10))
        {
            await _refreshTokenRepository.RevokeAllForUserAsync(
                reused.UserId,
                cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }

        if (existingRefreshToken is null ||
            existingRefreshToken.IsRevoked ||
            existingRefreshToken.IsExpired())
        {
            throw new InvalidOperationException(
                "Refresh token is invalid or expired.");
        }

        User user = existingRefreshToken.User;

        if (!user.IsActive || user.Status != UserStatus.Active)
        {
            throw new InvalidOperationException(
                "This account is not eligible for token refresh.");
        }

        existingRefreshToken.Revoke();

        JwtTokenResult jwtToken = _jwtTokenGenerator.GenerateToken(user);

        string refreshTokenValue = Convert.ToBase64String(
            RandomNumberGenerator.GetBytes(64));

        DateTime refreshTokenExpiresAt =
            DateTime.UtcNow.AddDays(7);

        var newRefreshToken = new RefreshTokenEntity(
            user.Id,
            refreshTokenValue,
            refreshTokenExpiresAt);

        await _refreshTokenRepository.AddAsync(
            newRefreshToken,
            cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new RefreshTokenResponse
        {
            AccessToken = jwtToken.AccessToken,
            AccessTokenExpiresAt = jwtToken.ExpiresAt,
            RefreshToken = refreshTokenValue
        };
    }
}
