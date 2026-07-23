using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.Login;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using System.Security.Cryptography;

namespace SmartMoney.Application.Features.Identity.Login;

public sealed class LoginUserCommandHandler
    : ICommandHandler<LoginUserCommand, LoginUserResponse>
{
    private readonly IUserRepository _userRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenGenerator _jwtTokenGenerator;
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IUnitOfWork _unitOfWork;
    private readonly LoginUserValidator _validator;

    public LoginUserCommandHandler(
        IUserRepository userRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenGenerator jwtTokenGenerator,
        IRefreshTokenRepository refreshTokenRepository,
        IUnitOfWork unitOfWork,
        LoginUserValidator validator)
    {
        _userRepository = userRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenGenerator = jwtTokenGenerator;
        _refreshTokenRepository = refreshTokenRepository;
        _unitOfWork = unitOfWork;
        _validator = validator;
    }

    public async Task<LoginUserResponse> HandleAsync(
        LoginUserCommand command,
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

        string email = command.Email.Trim().ToLowerInvariant();

        User? user = await _userRepository.GetByEmailAsync(
            email,
            cancellationToken);

        if (user is null)
        {
            throw new InvalidOperationException(
                "Invalid email or password.");
        }

        bool passwordMatches = _passwordHasher.Verify(
            command.Password,
            user.PasswordHash);

        if (!passwordMatches)
        {
            throw new InvalidOperationException(
                "Invalid email or password.");
        }

        if (!user.IsActive)
        {
            throw new InvalidOperationException(
                "Your account has been deactivated.");
        }

        if (user.Status != UserStatus.Active)
        {
            throw new InvalidOperationException(
                "Please verify your email address before logging in.");
        }

        JwtTokenResult jwtToken =
    _jwtTokenGenerator.GenerateToken(user);

        string refreshTokenValue = Convert.ToBase64String(
            RandomNumberGenerator.GetBytes(64));

        DateTime refreshTokenExpiresAt =
            DateTime.UtcNow.AddDays(7);

        var refreshToken = new RefreshToken(
            user.Id,
            refreshTokenValue,
            refreshTokenExpiresAt);

        await _refreshTokenRepository.AddAsync(
            refreshToken,
            cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new LoginUserResponse
        {
            UserId = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            AccessToken = jwtToken.AccessToken,
            AccessTokenExpiresAt = jwtToken.ExpiresAt,
            RefreshToken = refreshToken.Token
        };
    }
}