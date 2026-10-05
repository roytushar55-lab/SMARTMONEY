using Moq;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Identity.ResetPassword;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Identity;

public sealed class ResetPasswordHandlerTests
{
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IPasswordResetOtpRepository> _otps = new();
    private readonly Mock<IRefreshTokenRepository> _refreshTokens = new();
    private readonly Mock<IOtpHasher> _otpHasher = new();
    private readonly Mock<IPasswordHasher> _passwordHasher = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private ResetPasswordCommandHandler CreateHandler()
    {
        return new ResetPasswordCommandHandler(
            _users.Object,
            _otps.Object,
            _refreshTokens.Object,
            _otpHasher.Object,
            _passwordHasher.Object,
            _unitOfWork.Object,
            new ResetPasswordValidator());
    }

    private static User NewActiveUser()
    {
        var user = new User("Test User", "user@test.local", "9990001111", "old-hash", Guid.NewGuid());
        user.ActivateAccount();
        return user;
    }

    private static PasswordResetOtp NewOtp(Guid userId)
    {
        return new PasswordResetOtp(userId, "hashed-otp", DateTime.UtcNow.AddMinutes(2));
    }

    private void SetupValid(User user, PasswordResetOtp otp)
    {
        _users.Setup(u => u.GetByEmailAsync(user.Email, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _otps.Setup(o => o.GetLatestValidByUserIdAsync(user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(otp);
        _otpHasher.Setup(h => h.Verify("123456", "hashed-otp")).Returns(true);
        _passwordHasher.Setup(h => h.Hash("NewPassw0rd!")).Returns("new-hash");
    }

    [Fact]
    public async Task ValidOtp_ChangesPasswordAndRevokesExistingSessions()
    {
        var user = NewActiveUser();
        var otp = NewOtp(user.Id);
        SetupValid(user, otp);

        var response = await CreateHandler().HandleAsync(
            new ResetPasswordCommand(user.Email, "123456", "NewPassw0rd!"),
            CancellationToken.None);

        Assert.Equal("new-hash", user.PasswordHash);
        Assert.True(otp.IsUsed);
        _refreshTokens.Verify(
            r => r.RevokeAllForUserAsync(user.Id, It.IsAny<CancellationToken>()),
            Times.Once);
        Assert.Equal(user.Email, response.Email);
    }

    [Fact]
    public async Task RevocationHappens_AfterPasswordChangeIsSaved()
    {
        // If revocation ran before the password-change SaveChanges, a device
        // could refresh mid-request using the old session and still be
        // treated as valid for one more round-trip.
        var user = NewActiveUser();
        var otp = NewOtp(user.Id);
        SetupValid(user, otp);

        var saveOrder = new List<string>();
        _unitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .Callback(() => saveOrder.Add("save"))
            .ReturnsAsync(1);
        _refreshTokens.Setup(r => r.RevokeAllForUserAsync(user.Id, It.IsAny<CancellationToken>()))
            .Callback(() => saveOrder.Add("revoke"))
            .Returns(Task.CompletedTask);

        await CreateHandler().HandleAsync(
            new ResetPasswordCommand(user.Email, "123456", "NewPassw0rd!"), CancellationToken.None);

        Assert.Equal(new[] { "save", "revoke", "save" }, saveOrder);
    }

    [Fact]
    public async Task WrongOtp_Throws_AndDoesNotChangePassword()
    {
        var user = NewActiveUser();
        var otp = NewOtp(user.Id);
        SetupValid(user, otp);
        _otpHasher.Setup(h => h.Verify("000000", "hashed-otp")).Returns(false);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => CreateHandler().HandleAsync(
                new ResetPasswordCommand(user.Email, "000000", "NewPassw0rd!"),
                CancellationToken.None));

        Assert.Equal("old-hash", user.PasswordHash);
        _refreshTokens.Verify(
            r => r.RevokeAllForUserAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task UnknownEmail_Throws_SameMessageAsWrongOtp()
    {
        _users.Setup(u => u.GetByEmailAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        var unknownEx = await Assert.ThrowsAsync<InvalidOperationException>(
            () => CreateHandler().HandleAsync(
                new ResetPasswordCommand("nobody@test.local", "123456", "NewPassw0rd!"),
                CancellationToken.None));

        var user = NewActiveUser();
        var otp = NewOtp(user.Id);
        SetupValid(user, otp);
        _otpHasher.Setup(h => h.Verify("000000", "hashed-otp")).Returns(false);

        var wrongOtpEx = await Assert.ThrowsAsync<InvalidOperationException>(
            () => CreateHandler().HandleAsync(
                new ResetPasswordCommand(user.Email, "000000", "NewPassw0rd!"),
                CancellationToken.None));

        Assert.Equal(unknownEx.Message, wrongOtpEx.Message);
    }

    [Fact]
    public async Task ExpiredOrMissingOtp_Throws()
    {
        var user = NewActiveUser();
        _users.Setup(u => u.GetByEmailAsync(user.Email, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _otps.Setup(o => o.GetLatestValidByUserIdAsync(user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync((PasswordResetOtp?)null);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => CreateHandler().HandleAsync(
                new ResetPasswordCommand(user.Email, "123456", "NewPassw0rd!"),
                CancellationToken.None));
    }

    [Fact]
    public async Task DeactivatedUser_Throws()
    {
        // IsActive defaults true on construction and is a separate concept
        // from Status — only Deactivate() flips it, which is what this test
        // must exercise to actually hit the handler's IsActive guard.
        var user = new User("Test User", "user@test.local", "9990001111", "old-hash", Guid.NewGuid());
        user.ActivateAccount();
        user.Deactivate();
        _users.Setup(u => u.GetByEmailAsync(user.Email, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => CreateHandler().HandleAsync(
                new ResetPasswordCommand(user.Email, "123456", "NewPassw0rd!"),
                CancellationToken.None));

        _otps.Verify(
            o => o.GetLatestValidByUserIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Theory]
    [InlineData("")]
    [InlineData("short1")]
    public async Task WeakOrMissingPassword_Throws(string weakPassword)
    {
        await Assert.ThrowsAsync<ArgumentException>(
            () => CreateHandler().HandleAsync(
                new ResetPasswordCommand("user@test.local", "123456", weakPassword),
                CancellationToken.None));
    }

    [Fact]
    public async Task WrongOtp_CountsAsFailedAttempt_AndIsSaved()
    {
        var user = NewActiveUser();
        var otp = NewOtp(user.Id);
        SetupValid(user, otp);
        _otpHasher.Setup(h => h.Verify(It.IsAny<string>(), It.IsAny<string>())).Returns(false);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new ResetPasswordCommand(user.Email, "000000", "NewPassw0rd!"),
                CancellationToken.None));

        Assert.Equal(1, otp.FailedAttempts);
        Assert.False(otp.IsUsed);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public void Otp_DiesAfterMaxFailedAttempts()
    {
        var otp = NewOtp(Guid.NewGuid());

        for (var i = 0; i < SmartMoney.Domain.Common.OtpPolicy.MaxFailedAttempts; i++)
        {
            Assert.False(otp.IsLocked);
            otp.RegisterFailedAttempt();
        }

        Assert.True(otp.IsLocked);
    }
}
