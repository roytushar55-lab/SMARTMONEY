using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.ForgotPassword;
using SmartMoney.Domain.Common;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Identity.ForgotPassword;

public sealed class ForgotPasswordCommandHandler
    : ICommandHandler<ForgotPasswordCommand, ForgotPasswordResponse>
{
    private const string GenericMessage =
        "If an account exists for this email, a password reset code has been sent.";

    private readonly IUserRepository _userRepository;
    private readonly IPasswordResetOtpRepository _passwordResetOtpRepository;
    private readonly IOtpGenerator _otpGenerator;
    private readonly IOtpHasher _otpHasher;
    private readonly IEmailOtpSender _emailOtpSender;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ForgotPasswordValidator _validator;

    public ForgotPasswordCommandHandler(
        IUserRepository userRepository,
        IPasswordResetOtpRepository passwordResetOtpRepository,
        IOtpGenerator otpGenerator,
        IOtpHasher otpHasher,
        IEmailOtpSender emailOtpSender,
        IUnitOfWork unitOfWork,
        ForgotPasswordValidator validator)
    {
        _userRepository = userRepository;
        _passwordResetOtpRepository = passwordResetOtpRepository;
        _otpGenerator = otpGenerator;
        _otpHasher = otpHasher;
        _emailOtpSender = emailOtpSender;
        _unitOfWork = unitOfWork;
        _validator = validator;
    }

    public async Task<ForgotPasswordResponse> HandleAsync(
        ForgotPasswordCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        IReadOnlyCollection<string> validationErrors = _validator.Validate(command);

        if (validationErrors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", validationErrors));
        }

        string email = command.Email.Trim().ToLowerInvariant();

        var user = await _userRepository.GetByEmailAsync(email, cancellationToken);

        // Always return the same response whether or not the account exists,
        // is active, or is unverified — a different response would let an
        // attacker enumerate registered emails.
        if (user is not null && user.IsActive)
        {
            // Throttle silently: the response is identical either way, so this
            // neither reveals the account nor lets someone mint endless fresh
            // codes (each with a fresh set of guesses) or spam the inbox.
            DateTime now = DateTime.UtcNow;
            var recent = await _passwordResetOtpRepository.ListCreatedAtSinceAsync(
                user.Id,
                now.AddHours(-1),
                cancellationToken);

            if (!OtpPolicy.CanIssue(recent, now))
            {
                return new ForgotPasswordResponse { Message = GenericMessage };
            }

            string otp = _otpGenerator.Generate(6);
            string otpHash = _otpHasher.Hash(otp);
            DateTime otpExpiresAt = DateTime.UtcNow.AddMinutes(2);

            var passwordResetOtp = new PasswordResetOtp(user.Id, otpHash, otpExpiresAt);

            await _passwordResetOtpRepository.AddAsync(passwordResetOtp, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _emailOtpSender.SendPasswordResetOtpAsync(user.Email, otp, cancellationToken);
        }

        return new ForgotPasswordResponse { Message = GenericMessage };
    }
}
