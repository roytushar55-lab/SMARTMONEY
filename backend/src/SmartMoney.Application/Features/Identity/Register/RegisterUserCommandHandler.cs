using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.Register;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Identity.Register;

public sealed class RegisterUserCommandHandler
    : ICommandHandler<RegisterUserCommand, RegisterUserResponse>
{
    private readonly IUserRepository _userRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IUnitOfWork _unitOfWork;

    private readonly IEmailVerificationOtpRepository
    _emailVerificationOtpRepository;

    private readonly IOtpGenerator _otpGenerator;
    private readonly IOtpHasher _otpHasher;
    private readonly IEmailOtpSender _emailOtpSender;

    private readonly RegisterUserValidator _validator;

    public RegisterUserCommandHandler(
        IUserRepository userRepository,
        IWalletRepository walletRepository,
        IRoleRepository roleRepository,
        IPasswordHasher passwordHasher,
        IUnitOfWork unitOfWork,
        IEmailVerificationOtpRepository emailVerificationOtpRepository,
        IOtpGenerator otpGenerator,
        IOtpHasher otpHasher,
        IEmailOtpSender emailOtpSender,
        RegisterUserValidator validator)
    {
        _userRepository = userRepository;
        _walletRepository = walletRepository;
        _roleRepository = roleRepository;
        _passwordHasher = passwordHasher;
        _unitOfWork = unitOfWork;
        _emailVerificationOtpRepository = emailVerificationOtpRepository;
        _otpGenerator = otpGenerator;
        _otpHasher = otpHasher;
        _emailOtpSender = emailOtpSender;
        _validator = validator;
    }

    public async Task<RegisterUserResponse> HandleAsync(
        RegisterUserCommand command,
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

        string fullName = command.FullName.Trim();
        string email = command.Email.Trim().ToLowerInvariant();
        string phoneNumber = command.PhoneNumber.Trim();

        bool emailExists = await _userRepository.ExistsByEmailAsync(
            email,
            cancellationToken);

        if (emailExists)
        {
            throw new InvalidOperationException(
                "A user with this email address already exists.");
        }

        bool mobileExists = await _userRepository.ExistsByMobileAsync(
            phoneNumber,
            cancellationToken);

        if (mobileExists)
        {
            throw new InvalidOperationException(
                "A user with this phone number already exists.");
        }

        Role? customerRole = await _roleRepository.GetByNameAsync(
            RoleType.Customer,
            cancellationToken);

        if (customerRole is null)
        {
            throw new InvalidOperationException(
                "The Customer role is not configured.");
        }

        string passwordHash = _passwordHasher.Hash(command.Password);

        var user = new User(
            fullName,
            email,
            phoneNumber,
            passwordHash,
            customerRole.Id);

        var wallet = new Wallet(user.Id);

        string otp = _otpGenerator.Generate(6);

        string otpHash = _otpHasher.Hash(otp);

        DateTime otpExpiresAt =
            DateTime.UtcNow.AddMinutes(2);

        var emailVerificationOtp = new EmailVerificationOtp(
            user.Id,
            otpHash,
            otpExpiresAt);

        await _userRepository.AddAsync(
            user,
            cancellationToken);

        await _walletRepository.AddAsync(
            wallet,
            cancellationToken);

        await _emailVerificationOtpRepository.AddAsync(
            emailVerificationOtp,
            cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        await _emailOtpSender.SendAsync(
            user.Email,
            otp,
            cancellationToken);

        return new RegisterUserResponse
        {
            UserId = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            PhoneNumber = user.MobileNumber,
            ReferralCode = command.ReferralCode?.Trim() ?? string.Empty,
            IsEmailVerified = user.IsEmailVerified,
            IsPhoneVerified = user.IsMobileVerified
        };
    }
}