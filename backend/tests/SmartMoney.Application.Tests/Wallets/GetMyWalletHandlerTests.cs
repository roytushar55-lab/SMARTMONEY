using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Wallets.GetMyWallet;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Wallets;

public sealed class GetMyWalletHandlerTests
{
    private readonly Mock<IWalletRepository> _wallets = new();

    private GetMyWalletQueryHandler CreateHandler()
    {
        return new GetMyWalletQueryHandler(_wallets.Object);
    }

    [Fact]
    public async Task MissingWallet_ReturnsZerosWithoutCreating()
    {
        var response = await CreateHandler().HandleAsync(
            new GetMyWalletQuery(Guid.NewGuid()), CancellationToken.None);

        Assert.Equal(0m, response.AvailableBalance);
        Assert.Equal(0m, response.PendingBalance);
        Assert.Equal(0m, response.TotalEarned);
        Assert.Equal(0m, response.TotalWithdrawn);
        _wallets.Verify(
            w => w.AddAsync(It.IsAny<Wallet>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ExistingWallet_MapsAllBalances()
    {
        var userId = Guid.NewGuid();
        var wallet = new Wallet(userId);
        wallet.AddPendingCashback(200.00m);
        wallet.ApproveCashback(150.00m);
        wallet.Withdraw(50.00m);
        _wallets.Setup(w => w.GetByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(wallet);

        var response = await CreateHandler().HandleAsync(
            new GetMyWalletQuery(userId), CancellationToken.None);

        Assert.Equal(100.00m, response.AvailableBalance);
        Assert.Equal(50.00m, response.PendingBalance);
        Assert.Equal(150.00m, response.TotalEarned);
        Assert.Equal(50.00m, response.TotalWithdrawn);
        Assert.Equal(0m, response.HeldBalance);
    }

    [Fact]
    public async Task HeldBalance_IsReportedSeparatelyFromAvailable()
    {
        var userId = Guid.NewGuid();
        var wallet = new Wallet(userId);
        wallet.AddPendingCashback(500.00m);
        wallet.ApproveCashback(500.00m);
        wallet.HoldForWithdrawal(300.00m);
        _wallets.Setup(w => w.GetByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(wallet);

        var response = await CreateHandler().HandleAsync(
            new GetMyWalletQuery(userId), CancellationToken.None);

        Assert.Equal(200.00m, response.AvailableBalance);
        Assert.Equal(300.00m, response.HeldBalance);
    }
}
