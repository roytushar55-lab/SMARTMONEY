using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks.ApproveCashback;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Cashbacks;

public sealed class ApproveCashbackHandlerTests
{
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();
    private readonly Mock<ICashbackEventRepository> _events = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Guid _reviewerId = Guid.NewGuid();

    private readonly Guid _userId = Guid.NewGuid();
    private readonly Wallet _wallet;

    public ApproveCashbackHandlerTests()
    {
        _wallet = new Wallet(_userId);

        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
    }

    private ApproveCashbackCommandHandler CreateHandler()
    {
        return new ApproveCashbackCommandHandler(
            _cashbacks.Object,
            _wallets.Object,
            _walletTransactions.Object,
            _events.Object,
            _unitOfWork.Object);
    }

    private Cashback NewCashback(decimal amount = 150.00m, string? networkStatus = "validated")
    {
        var cashback = new Cashback(
            _userId, _wallet.Id, Guid.NewGuid(), amount, DateTime.UtcNow.AddDays(60));

        // The conversion rides along on a loaded cashback; approval is only
        // allowed once the network says validated, so these tests carry that.
        typeof(Cashback).GetProperty(nameof(Cashback.AffiliateConversion))!
            .SetValue(cashback, new AffiliateConversion { NetworkStatus = networkStatus ?? string.Empty });

        _cashbacks.Setup(c => c.GetByIdAsync(cashback.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(cashback);

        return cashback;
    }

    [Fact]
    public async Task PendingOrigin_ConfirmsAndMovesPendingToAvailable()
    {
        var cashback = NewCashback();
        cashback.FlagForReview();
        _wallet.AddPendingCashback(150.00m);
        WalletTransaction? entry = null;
        _walletTransactions.Setup(t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()))
            .Callback<WalletTransaction, CancellationToken>((tx, _) => entry = tx);

        var response = await CreateHandler().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("Confirmed", response!.Status);
        Assert.Equal(CashbackStatus.Confirmed, cashback.Status);
        Assert.NotNull(cashback.ConfirmedDate);
        Assert.Equal(0m, _wallet.PendingBalance);
        Assert.Equal(150.00m, _wallet.AvailableBalance);
        Assert.Equal(150.00m, _wallet.TotalEarned);
        Assert.NotNull(entry);
        Assert.Equal(WalletTransactionType.CashbackConfirmed, entry!.Type);
        Assert.Equal(150.00m, entry.AvailableBalanceAfter);
        Assert.Equal(0m, entry.PendingBalanceAfter);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task DirectlyFromPending_AlsoCredits()
    {
        // Confirm() is reachable straight from Pending (out-of-band evidence).
        var cashback = NewCashback();
        _wallet.AddPendingCashback(150.00m);

        var response = await CreateHandler().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal(150.00m, _wallet.AvailableBalance);
    }

    [Fact]
    public async Task PreviouslyConfirmedOrigin_DoesNotDoubleCredit()
    {
        // Confirmed -> FlagForReview (network suggested a reversal) -> admin
        // re-approves. The money already sits in Available; a second credit
        // would double-pay the user.
        var cashback = NewCashback();
        _wallet.AddPendingCashback(150.00m);
        cashback.Confirm();
        _wallet.ApproveCashback(150.00m);
        cashback.FlagForReview();

        var response = await CreateHandler().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal(CashbackStatus.Confirmed, cashback.Status);
        Assert.Equal(150.00m, _wallet.AvailableBalance);
        Assert.Equal(150.00m, _wallet.TotalEarned);
        Assert.Equal(0m, _wallet.PendingBalance);
        _walletTransactions.Verify(
            t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()),
            Times.Never);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnknownCashback_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new ApproveCashbackCommand(Guid.NewGuid(), _reviewerId), CancellationToken.None);

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
                new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None));

        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _walletTransactions.Verify(
            t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task InsufficientPendingBalance_ThrowsWithoutSaving()
    {
        // Pre-M4 cashback rows exist without a matching pending credit; the
        // approve must surface that instead of silently minting money.
        var cashback = NewCashback();
        cashback.FlagForReview();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None));

        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
