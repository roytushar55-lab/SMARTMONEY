using Moq;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Identity.DeleteAccount;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Identity;

public sealed class DeleteAccountHandlerTests
{
    private const string Password = "Passw0rd!";

    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<IWalletTransactionRepository> _transactions = new();
    private readonly Mock<IRefreshTokenRepository> _refreshTokens = new();
    private readonly Mock<IDeletedUserArchiveRepository> _archives = new();
    private readonly Mock<IPasswordHasher> _hasher = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private readonly User _user;
    private readonly Wallet _wallet;

    public DeleteAccountHandlerTests()
    {
        _user = new User(
            "Test User",
            "test@example.com",
            "9876543210",
            "hash",
            Guid.NewGuid());
        _user.UpdateProfileImageUrl("https://example.com/photo.jpg");

        _wallet = new Wallet(_user.Id);

        _users.Setup(u => u.GetByIdAsync(_user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_user);
        _wallets.Setup(w => w.GetByUserIdAsync(_user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
        _cashbacks.Setup(c => c.ListUnconfirmedByUserIdAsync(
                _user.Id,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Cashback>());
        _hasher.Setup(h => h.Verify(Password, "hash")).Returns(true);
    }

    private DeleteAccountCommandHandler CreateHandler()
    {
        return new DeleteAccountCommandHandler(
            _users.Object,
            _wallets.Object,
            _cashbacks.Object,
            _transactions.Object,
            _refreshTokens.Object,
            _archives.Object,
            _hasher.Object,
            _unitOfWork.Object);
    }

    [Fact]
    public async Task Handle_WithWrongPassword_Throws_AndChangesNothing()
    {
        var handler = CreateHandler();

        await Assert.ThrowsAsync<ArgumentException>(() =>
            handler.HandleAsync(
                new DeleteAccountCommand(_user.Id, "wrong"),
                CancellationToken.None));

        Assert.Equal("test@example.com", _user.Email);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task Handle_WithBlankPassword_Throws()
    {
        var handler = CreateHandler();

        await Assert.ThrowsAsync<ArgumentException>(() =>
            handler.HandleAsync(
                new DeleteAccountCommand(_user.Id, "  "),
                CancellationToken.None));
    }

    [Fact]
    public async Task Handle_WithAvailableBalance_Throws_AndKeepsAccount()
    {
        _wallet.AddPendingCashback(50);
        _wallet.ApproveCashback(50);
        var handler = CreateHandler();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            handler.HandleAsync(
                new DeleteAccountCommand(_user.Id, Password),
                CancellationToken.None));

        Assert.NotEqual(UserStatus.Deleted, _user.Status);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task Handle_WithUnknownUser_ThrowsNotFound()
    {
        var handler = CreateHandler();

        await Assert.ThrowsAsync<KeyNotFoundException>(() =>
            handler.HandleAsync(
                new DeleteAccountCommand(Guid.NewGuid(), Password),
                CancellationToken.None));
    }

    [Fact]
    public async Task Handle_Success_AnonymizesUser_RevokesTokens_AndSaves()
    {
        var handler = CreateHandler();

        var result = await handler.HandleAsync(
            new DeleteAccountCommand(_user.Id, Password),
            CancellationToken.None);

        Assert.Equal("https://example.com/photo.jpg", result.PreviousProfileImageUrl);
        Assert.Equal(UserStatus.Deleted, _user.Status);
        Assert.False(_user.IsActive);
        Assert.Equal("Deleted user", _user.FullName);
        Assert.DoesNotContain("test@example.com", _user.Email);
        Assert.NotEqual("9876543210", _user.MobileNumber);
        Assert.Null(_user.PasswordHash);
        Assert.Null(_user.ProfileImageUrl);

        _refreshTokens.Verify(
            r => r.RevokeAllForUserAsync(_user.Id, It.IsAny<CancellationToken>()),
            Times.Once);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Handle_Success_ForfeitsPendingCashback()
    {
        var cashback = new Cashback(
            _user.Id,
            _wallet.Id,
            Guid.NewGuid(),
            30,
            DateTime.UtcNow.AddDays(30));
        _wallet.AddPendingCashback(30);
        _cashbacks.Setup(c => c.ListUnconfirmedByUserIdAsync(
                _user.Id,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Cashback> { cashback });
        var handler = CreateHandler();

        var result = await handler.HandleAsync(
            new DeleteAccountCommand(_user.Id, Password),
            CancellationToken.None);

        Assert.Equal(30, result.ForfeitedPendingCashback);
        Assert.Equal(CashbackStatus.Rejected, cashback.Status);
        Assert.Equal(0, _wallet.PendingBalance);
        _transactions.Verify(
            t => t.AddAsync(
                It.Is<WalletTransaction>(x =>
                    x.Type == WalletTransactionType.CashbackRejected),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Handle_Success_ArchivesOriginalDetailsFor90Days()
    {
        DeletedUserArchive? saved = null;
        _archives.Setup(a => a.AddAsync(
                It.IsAny<DeletedUserArchive>(),
                It.IsAny<CancellationToken>()))
            .Callback<DeletedUserArchive, CancellationToken>((a, _) => saved = a)
            .Returns(Task.CompletedTask);
        var handler = CreateHandler();

        await handler.HandleAsync(
            new DeleteAccountCommand(_user.Id, Password),
            CancellationToken.None);

        Assert.NotNull(saved);
        Assert.Equal(_user.Id, saved!.UserId);
        Assert.Equal("Test User", saved.FullName);
        Assert.Equal("test@example.com", saved.Email);
        Assert.Equal("9876543210", saved.MobileNumber);
        Assert.Equal(90, Math.Round((saved.PurgeAfter - saved.DeletedAt).TotalDays));
    }

    [Fact]
    public async Task Handle_WithWrongPassword_ArchivesNothing()
    {
        var handler = CreateHandler();

        await Assert.ThrowsAsync<ArgumentException>(() =>
            handler.HandleAsync(
                new DeleteAccountCommand(_user.Id, "wrong"),
                CancellationToken.None));

        _archives.Verify(
            a => a.AddAsync(
                It.IsAny<DeletedUserArchive>(),
                It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
