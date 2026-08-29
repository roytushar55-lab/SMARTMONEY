using System.Security.Cryptography;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.Login;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using RefreshTokenEntity = SmartMoney.Domain.Entities.RefreshToken;

namespace SmartMoney.Application.Features.Identity.GoogleLogin;

/// <summary>
/// New-user, existing-Google-user and existing-password-user (linked by
/// verified email) all fall out of the same lookup chain below — see each
/// branch's comment for which case it handles.
/// </summary>
public sealed class LoginWithGoogleCommandHandler
    : ICommandHandler<LoginWithGoogleCommand, LoginUserResponse>
{
    private readonly IGoogleIdTokenVerifier _googleIdTokenVerifier;
    private readonly IUserRepository _userRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly IJwtTokenGenerator _jwtTokenGenerator;
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IUnitOfWork _unitOfWork;
    private readonly LoginWithGoogleValidator _validator;

    public LoginWithGoogleCommandHandler(
        IGoogleIdTokenVerifier googleIdTokenVerifier,
        IUserRepository userRepository,
        IWalletRepository walletRepository,
        IRoleRepository roleRepository,
        IJwtTokenGenerator jwtTokenGenerator,
        IRefreshTokenRepository refreshTokenRepository,
        IUnitOfWork unitOfWork,
        LoginWithGoogleValidator validator)
    {
        _googleIdTokenVerifier = googleIdTokenVerifier;
        _userRepository = userRepository;
        _walletRepository = walletRepository;
        _roleRepository = roleRepository;
        _jwtTokenGenerator = jwtTokenGenerator;
        _refreshTokenRepository = refreshTokenRepository;
        _unitOfWork = unitOfWork;
        _validator = validator;
    }

    public async Task<LoginUserResponse> HandleAsync(
        LoginWithGoogleCommand command,
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

        GoogleIdTokenPayload? payload = await _googleIdTokenVerifier.VerifyAsync(
            command.IdToken,
            cancellationToken);

        if (payload is null)
        {
            throw new InvalidOperationException(
                "Google sign-in couldn't be verified. Please try again.");
        }

        if (!payload.EmailVerified)
        {
            throw new InvalidOperationException(
                "Your Google account's email address must be verified.");
        }

        string email = payload.Email.Trim().ToLowerInvariant();

        // Case 1: this Google account has signed in here before.
        User? user = await _userRepository.GetByGoogleIdAsync(
            payload.Subject,
            cancellationToken);

        if (user is null)
        {
            // Case 2: an account already exists for this (Google-verified)
            // email — link rather than silently creating a duplicate.
            user = await _userRepository.GetByEmailAsync(
                email,
                cancellationToken);

            if (user is not null)
            {
                user.LinkGoogleAccount(payload.Subject);
            }
        }

        if (user is null)
        {
            // Case 3: genuinely new — create the account and its wallet, the
            // same pair RegisterUserCommandHandler creates for a normal
            // signup.
            Role? customerRole = await _roleRepository.GetByNameAsync(
                RoleType.Customer,
                cancellationToken);

            if (customerRole is null)
            {
                throw new InvalidOperationException(
                    "The Customer role is not configured.");
            }

            user = User.CreateFromGoogle(
                payload.FullName,
                email,
                payload.Subject,
                customerRole);

            var wallet = new Wallet(user.Id);

            await _userRepository.AddAsync(user, cancellationToken);
            await _walletRepository.AddAsync(wallet, cancellationToken);
        }

        if (!user.IsActive)
        {
            throw new InvalidOperationException(
                "Your account has been deactivated.");
        }

        if (user.Status is UserStatus.Suspended or UserStatus.Blocked or UserStatus.Deleted)
        {
            throw new InvalidOperationException(
                "Your account is not available. Please contact support.");
        }

        JwtTokenResult jwtToken = _jwtTokenGenerator.GenerateToken(user);

        string refreshTokenValue = Convert.ToBase64String(
            RandomNumberGenerator.GetBytes(64));

        DateTime refreshTokenExpiresAt = DateTime.UtcNow.AddDays(7);

        var refreshToken = new RefreshTokenEntity(
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
