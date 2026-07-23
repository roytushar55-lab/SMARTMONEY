using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.ResendEmailOtp;
using SmartMoney.Domain.Enums;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Identity.ResendEmailOtp;

public sealed class ResendEmailOtpCommandHandler
    : ICommandHandler<ResendEmailOtpCommand, ResendEmailOtpResponse>
{
    private readonly IUserRepository _userRepository;

    private readonly IEmailVerificationOtpRepository
        _emailVerificationOtpRepository;

    private readonly IOtpGenerator _otpGenerator;
    private readonly IOtpHasher _otpHasher;
    private readonly IEmailOtpSender _emailOtpSender;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ResendEmailOtpValidator _validator;

    public ResendEmailOtpCommandHandler(
        IUserRepository userRepository,
        IEmailVerificationOtpRepository emailVerificationOtpRepository,
        IOtpGenerator otpGenerator,
        IOtpHasher otpHasher,
        IEmailOtpSender emailOtpSender,
        IUnitOfWork unitOfWork,
        ResendEmailOtpValidator validator)
    {
        _userRepository = userRepository;

        _emailVerificationOtpRepository =
            emailVerificationOtpRepository;

        _otpGenerator = otpGenerator;
        _otpHasher = otpHasher;
        _emailOtpSender = emailOtpSender;
        _unitOfWork = unitOfWork;
        _validator = validator;
    }

    public async Task<ResendEmailOtpResponse> HandleAsync(
        ResendEmailOtpCommand command,
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

        var user = await _userRepository.GetByEmailAsync(
            email,
            cancellationToken);

        if (user is null)
        {
            throw new InvalidOperationException(
                "No account was found with this email address.");
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

        string otp = _otpGenerator.Generate(6);

        string otpHash = _otpHasher.Hash(otp);

        DateTime otpExpiresAt =
            DateTime.UtcNow.AddMinutes(2);

        var emailVerificationOtp = new EmailVerificationOtp(
            user.Id,
            otpHash,
            otpExpiresAt);

        await _emailVerificationOtpRepository.AddAsync(
            emailVerificationOtp,
            cancellationToken);

        await _unitOfWork.SaveChangesAsync(
            cancellationToken);

        await _emailOtpSender.SendAsync(
            user.Email,
            otp,
            cancellationToken);

        return new ResendEmailOtpResponse
        {
            Email = user.Email,
            ExpiresAt = otpExpiresAt,
            Message = "A new verification OTP has been generated."
        };
    }
}