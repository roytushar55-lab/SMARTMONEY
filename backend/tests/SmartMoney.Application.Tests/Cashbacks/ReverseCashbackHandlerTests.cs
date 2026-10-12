using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks.ReverseCashback;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Cashbacks;

public sealed class ReverseCashbackHandlerTests
{
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();
    private readonly Mock<ICashbackEventRepository> _events = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Guid _reviewerId = Guid.NewGuid();

    private readonly Guid _userId = Guid.NewGuid();
    private readonly Wallet _wallet;

    public ReverseCashbackHandlerTests()
    {
        _wallet = new Wallet(_userId);

        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
    }

    private ReverseCashbackCommandHandler CreateHandler()
    {
        return new ReverseCashbackCommandHandler(
            _cashbacks.Object,
            _wallets.Object,
            _walletTransactions.Object,
            _events.Object,
            _unitOfWork.Object);
    }

    private Cashback ConfirmedFlaggedCashback(decimal amount = 150.00m)
    {
        // The only state Reverse() accepts: previously confirmed, then
        // flagged back into review by a network "reversed" postback.
        var cashback = new Cashback(
            _userId, _wallet.Id, Guid.NewGuid(), amount, DateTime.UtcNow.AddDays(60));
        _wallet.AddPendingCashback(amount);
        cashback.Confirm();
        _wallet.ApproveCashback(amount);
        cashback.FlagForReview();

        _cashbacks.Setup(c => c.GetByIdAsync(cashback.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(cashback);

        return cashback;
    }

    [Fact]
    public async Task ConfirmedThenFlagged_ReversesAndDebitsAvailable()
    {
        var cashback = ConfirmedFlaggedCashback();
        WalletTransaction? entry = null;
        _walletTransactions.Setup(t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()))
            .Callback<WalletTransaction, CancellationToken>((tx, _) => entry = tx);

        var response = await CreateHandler().HandleAsync(
            new ReverseCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("Reversed", response!.Status);
        Assert.Equal(CashbackStatus.Reversed, cashback.Status);
        Assert.Equal(0m, _wallet.AvailableBalance);
        Assert.Equal(0m, _wallet.TotalEarned);
        Assert.NotNull(entry);
        Assert.Equal(WalletTransactionType.CashbackReversed, entry!.Type);
        Assert.Equal(0m, entry.AvailableBalanceAfter);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task NeverConfirmedUnderReview_ThrowsWithoutSaving()
    {
        // Domain guard: reverse requires a prior confirmation.
        var cashback = new Cashback(
            _userId, _wallet.Id, Guid.NewGuid(), 150.00m, DateTime.UtcNow.AddDays(60));
        cashback.FlagForReview();
        _cashbacks.Setup(c => c.GetByIdAsync(cashback.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(cashback);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new ReverseCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None));

        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task MoneyHeldForAWithdrawal_ThrowsAnExplainingMessageWithoutSaving()
    {
        var cashback = ConfirmedFlaggedCashback();
        _wallet.HoldForWithdrawal(100.00m);

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new ReverseCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None));

        // The admin sees this text in the 409 response.
        Assert.Contains("held for a pending withdrawal", exception.Message);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task UserAlreadyWithdrew_ThrowsWithoutSaving()
    {
        var cashback = ConfirmedFlaggedCashback();
        _wallet.Withdraw(100.00m);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new ReverseCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None));

        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _walletTransactions.Verify(
            t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task UnknownCashback_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new ReverseCashbackCommand(Guid.NewGuid(), _reviewerId, "test reason"), CancellationToken.None);

        Assert.Null(response);
    }
}
