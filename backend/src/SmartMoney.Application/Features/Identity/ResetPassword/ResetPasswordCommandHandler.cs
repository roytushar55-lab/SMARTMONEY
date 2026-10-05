using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.ResetPassword;

namespace SmartMoney.Application.Features.Identity.ResetPassword;

public sealed class ResetPasswordCommandHandler
    : ICommandHandler<ResetPasswordCommand, ResetPasswordResponse>
{
    private readonly IUserRepository _userRepository;
    private readonly IPasswordResetOtpRepository _passwordResetOtpRepository;
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IOtpHasher _otpHasher;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ResetPasswordValidator _validator;

    public ResetPasswordCommandHandler(
        IUserRepository userRepository,
        IPasswordResetOtpRepository passwordResetOtpRepository,
        IRefreshTokenRepository refreshTokenRepository,
        IOtpHasher otpHasher,
        IPasswordHasher passwordHasher,
        IUnitOfWork unitOfWork,
        ResetPasswordValidator validator)
    {
        _userRepository = userRepository;
        _passwordResetOtpRepository = passwordResetOtpRepository;
        _refreshTokenRepository = refreshTokenRepository;
        _otpHasher = otpHasher;
        _passwordHasher = passwordHasher;
        _unitOfWork = unitOfWork;
        _validator = validator;
    }

    public async Task<ResetPasswordResponse> HandleAsync(
        ResetPasswordCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        IReadOnlyCollection<string> validationErrors = _validator.Validate(command);

        if (validationErrors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", validationErrors));
        }

        string email = command.Email.Trim().ToLowerInvariant();
        string otpCode = command.Otp.Trim();

        var user = await _userRepository.GetByEmailAsync(email, cancellationToken);

        // Same message whether the email, OTP, or account state is wrong —
        // never tell an attacker which part of the guess was correct.
        const string invalidMessage = "Invalid email or OTP.";

        if (user is null || !user.IsActive)
        {
            throw new InvalidOperationException(invalidMessage);
        }

        var passwordResetOtp = await _passwordResetOtpRepository
            .GetLatestValidByUserIdAsync(user.Id, cancellationToken);

        if (passwordResetOtp is null)
        {
            throw new InvalidOperationException(invalidMessage);
        }

        bool otpMatches = _otpHasher.Verify(otpCode, passwordResetOtp.CodeHash);

        if (!otpMatches)
        {
            // Count the miss before rejecting: after MaxFailedAttempts wrong
            // guesses this code is dead, so a 6-digit code cannot be brute
            // forced inside its lifetime.
            passwordResetOtp.RegisterFailedAttempt();
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            throw new InvalidOperationException(invalidMessage);
        }

        passwordResetOtp.MarkAsUsed();

        string newPasswordHash = _passwordHasher.Hash(command.NewPassword);
        user.ChangePasswordHash(newPasswordHash);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        // A device that was signed in before the reset must not stay signed
        // in after it — the whole point of resetting a password is to lock
        // out anyone who had access under the old one.
        await _refreshTokenRepository.RevokeAllForUserAsync(user.Id, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new ResetPasswordResponse
        {
            Email = user.Email,
            Message = "Password has been reset. Please log in with your new password."
        };
    }
}
