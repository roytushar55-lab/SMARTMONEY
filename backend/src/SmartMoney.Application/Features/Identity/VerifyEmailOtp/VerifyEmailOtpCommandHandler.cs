using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.VerifyEmailOtp;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Identity.VerifyEmailOtp;

public sealed class VerifyEmailOtpCommandHandler
    : ICommandHandler<VerifyEmailOtpCommand, VerifyEmailOtpResponse>
{
    private readonly IUserRepository _userRepository;

    private readonly IEmailVerificationOtpRepository
        _emailVerificationOtpRepository;

    private readonly IOtpHasher _otpHasher;
    private readonly IUnitOfWork _unitOfWork;
    private readonly VerifyEmailOtpValidator _validator;

    public VerifyEmailOtpCommandHandler(
        IUserRepository userRepository,
        IEmailVerificationOtpRepository emailVerificationOtpRepository,
        IOtpHasher otpHasher,
        IUnitOfWork unitOfWork,
        VerifyEmailOtpValidator validator)
    {
        _userRepository = userRepository;

        _emailVerificationOtpRepository =
            emailVerificationOtpRepository;

        _otpHasher = otpHasher;
        _unitOfWork = unitOfWork;
        _validator = validator;
    }

    public async Task<VerifyEmailOtpResponse> HandleAsync(
        VerifyEmailOtpCommand command,
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

        string email =
            command.Email.Trim().ToLowerInvariant();

        string otpCode =
            command.Otp.Trim();

        var user = await _userRepository.GetByEmailAsync(
            email,
            cancellationToken);

        if (user is null)
        {
            throw new InvalidOperationException(
                "Invalid email or OTP.");
        }

        if (!user.IsActive)
        {
            throw new InvalidOperationException(
                "Your account has been deactivated.");
        }

        if (user.IsEmailVerified)
        {
            throw new InvalidOperationException(
                "Email address is already verified.");
        }

        if (user.Status != UserStatus.Pending)
        {
            throw new InvalidOperationException(
                "This account is not eligible for email verification.");
        }

        var emailVerificationOtp =
            await _emailVerificationOtpRepository
                .GetLatestValidByUserIdAsync(
                    user.Id,
                    cancellationToken);

        if (emailVerificationOtp is null)
        {
            throw new InvalidOperationException(
                "OTP is invalid or has expired.");
        }

        bool otpMatches = _otpHasher.Verify(
            otpCode,
            emailVerificationOtp.CodeHash);

        if (!otpMatches)
        {
            throw new InvalidOperationException(
                "Invalid email or OTP.");
        }

        emailVerificationOtp.MarkAsUsed();

        user.VerifyEmail();
        user.ActivateAccount();

        await _unitOfWork.SaveChangesAsync(
            cancellationToken);

        return new VerifyEmailOtpResponse
        {
            UserId = user.Id,
            Email = user.Email,
            IsEmailVerified = user.IsEmailVerified,
            Status = user.Status.ToString()
        };
    }
}