using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks.RejectCashback;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Cashbacks;

public sealed class RejectCashbackHandlerTests
{
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();
    private readonly Mock<ICashbackEventRepository> _events = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Guid _reviewerId = Guid.NewGuid();

    private readonly Guid _userId = Guid.NewGuid();
    private readonly Wallet _wallet;

    public RejectCashbackHandlerTests()
    {
        _wallet = new Wallet(_userId);

        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
    }

    private RejectCashbackCommandHandler CreateHandler()
    {
        return new RejectCashbackCommandHandler(
            _cashbacks.Object,
            _wallets.Object,
            _walletTransactions.Object,
            _events.Object,
            _unitOfWork.Object);
    }

    private Cashback NewCashback(decimal amount = 150.00m)
    {
        var cashback = new Cashback(
            _userId, _wallet.Id, Guid.NewGuid(), amount, DateTime.UtcNow.AddDays(60));

        _cashbacks.Setup(c => c.GetByIdAsync(cashback.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(cashback);

        return cashback;
    }

    [Fact]
    public async Task PendingOrigin_RejectsAndRemovesPendingBalance()
    {
        var cashback = NewCashback();
        cashback.FlagForReview();
        _wallet.AddPendingCashback(150.00m);
        WalletTransaction? entry = null;
        _walletTransactions.Setup(t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()))
            .Callback<WalletTransaction, CancellationToken>((tx, _) => entry = tx);

        var response = await CreateHandler().HandleAsync(
            new RejectCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("Rejected", response!.Status);
        Assert.Equal(CashbackStatus.Rejected, cashback.Status);
        Assert.Equal(0m, _wallet.PendingBalance);
        Assert.Equal(0m, _wallet.AvailableBalance);
        Assert.NotNull(entry);
        Assert.Equal(WalletTransactionType.CashbackRejected, entry!.Type);
        Assert.Equal(0m, entry.PendingBalanceAfter);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task PreviouslyConfirmed_ThrowsPointingToReverse()
    {
        // After a Confirm the money sits in Available, not Pending — reject
        // would debit the wrong bucket. The admin must use reverse.
        var cashback = NewCashback();
        _wallet.AddPendingCashback(150.00m);
        cashback.Confirm();
        _wallet.ApproveCashback(150.00m);
        cashback.FlagForReview();

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new RejectCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None));

        Assert.Contains("reverse", exception.Message);
        Assert.Equal(150.00m, _wallet.AvailableBalance);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, cashback.Status);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task UnknownCashback_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new RejectCashbackCommand(Guid.NewGuid(), _reviewerId, "test reason"), CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task AlreadyRejected_ThrowsWithoutSaving()
    {
        var cashback = NewCashback();
        cashback.Reject();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new RejectCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None));

        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
