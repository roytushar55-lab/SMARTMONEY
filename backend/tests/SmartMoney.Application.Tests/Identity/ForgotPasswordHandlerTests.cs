using Moq;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Identity.ForgotPassword;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Identity;

public sealed class ForgotPasswordHandlerTests
{
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IPasswordResetOtpRepository> _otps = new();
    private readonly Mock<IOtpGenerator> _otpGenerator = new();
    private readonly Mock<IOtpHasher> _otpHasher = new();
    private readonly Mock<IEmailOtpSender> _emailSender = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    public ForgotPasswordHandlerTests()
    {
        // No recently issued codes unless a test says otherwise.
        _otps.Setup(o => o.ListCreatedAtSinceAsync(
                It.IsAny<Guid>(),
                It.IsAny<DateTime>(),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<DateTime>());
    }

    private ForgotPasswordCommandHandler CreateHandler()
    {
        return new ForgotPasswordCommandHandler(
            _users.Object,
            _otps.Object,
            _otpGenerator.Object,
            _otpHasher.Object,
            _emailSender.Object,
            _unitOfWork.Object,
            new ForgotPasswordValidator());
    }

    private static User NewUser(bool active = true)
    {
        var user = new User("Test User", "user@test.local", "9990001111", "hash", Guid.NewGuid());
        user.ActivateAccount();

        // IsActive defaults to true on construction and Status is a separate
        // concept — Deactivate() is the only thing that flips IsActive false.
        if (!active)
        {
            user.Deactivate();
        }

        return user;
    }

    [Fact]
    public async Task ExistingActiveUser_GeneratesAndSendsOtp()
    {
        var user = NewUser();
        _users.Setup(u => u.GetByEmailAsync("user@test.local", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _otpGenerator.Setup(g => g.Generate(6)).Returns("123456");
        _otpHasher.Setup(h => h.Hash("123456")).Returns("hashed-otp");

        var response = await CreateHandler().HandleAsync(
            new ForgotPasswordCommand("user@test.local"), CancellationToken.None);

        _otps.Verify(
            o => o.AddAsync(
                It.Is<PasswordResetOtp>(otp => otp.UserId == user.Id),
                It.IsAny<CancellationToken>()),
            Times.Once);
        _emailSender.Verify(
            e => e.SendPasswordResetOtpAsync("user@test.local", "123456", It.IsAny<CancellationToken>()),
            Times.Once);
        Assert.False(string.IsNullOrWhiteSpace(response.Message));
    }

    [Fact]
    public async Task UnknownEmail_ReturnsSameGenericResponse_WithoutSendingAnything()
    {
        _users.Setup(u => u.GetByEmailAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        var response = await CreateHandler().HandleAsync(
            new ForgotPasswordCommand("nobody@test.local"), CancellationToken.None);

        _otps.Verify(
            o => o.AddAsync(It.IsAny<PasswordResetOtp>(), It.IsAny<CancellationToken>()),
            Times.Never);
        _emailSender.Verify(
            e => e.SendPasswordResetOtpAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
        Assert.False(string.IsNullOrWhiteSpace(response.Message));
    }

    [Fact]
    public async Task InactiveUser_ReturnsSameGenericResponse_WithoutSendingAnything()
    {
        // Same response as "unknown email" is the point: no signal an
        // attacker could use to tell the two cases apart.
        var user = NewUser(active: false);
        _users.Setup(u => u.GetByEmailAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        var knownResponse = await CreateHandler().HandleAsync(
            new ForgotPasswordCommand("user@test.local"), CancellationToken.None);

        _users.Setup(u => u.GetByEmailAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        var unknownResponse = await CreateHandler().HandleAsync(
            new ForgotPasswordCommand("nobody@test.local"), CancellationToken.None);

        Assert.Equal(knownResponse.Message, unknownResponse.Message);
        _emailSender.Verify(
            e => e.SendPasswordResetOtpAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task InvalidEmailFormat_Throws()
    {
        await Assert.ThrowsAsync<ArgumentException>(
            () => CreateHandler().HandleAsync(
                new ForgotPasswordCommand("not-an-email"), CancellationToken.None));
    }

    [Fact]
    public async Task RecentlyIssuedCode_IsThrottled_SameResponse_NoEmail()
    {
        var user = NewUser();
        _users.Setup(u => u.GetByEmailAsync(user.Email, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _otps.Setup(o => o.ListCreatedAtSinceAsync(
                user.Id, It.IsAny<DateTime>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<DateTime> { DateTime.UtcNow.AddSeconds(-10) });

        var response = await CreateHandler().HandleAsync(
            new ForgotPasswordCommand(user.Email),
            CancellationToken.None);

        Assert.NotNull(response.Message);
        _emailSender.Verify(
            e => e.SendPasswordResetOtpAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task TooManyCodesInAnHour_IsThrottled()
    {
        var user = NewUser();
        _users.Setup(u => u.GetByEmailAsync(user.Email, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        var spread = Enumerable.Range(1, 5)
            .Select(i => DateTime.UtcNow.AddMinutes(-10 * i))
            .ToList();
        _otps.Setup(o => o.ListCreatedAtSinceAsync(
                user.Id, It.IsAny<DateTime>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(spread);

        await CreateHandler().HandleAsync(
            new ForgotPasswordCommand(user.Email),
            CancellationToken.None);

        _emailSender.Verify(
            e => e.SendPasswordResetOtpAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
