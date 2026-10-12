using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Domain;

public sealed class WalletTests
{
    private static Wallet NewWallet() => new(Guid.NewGuid());

    [Fact]
    public void AddPendingCashback_CreditsPendingOnly()
    {
        var wallet = NewWallet();

        wallet.AddPendingCashback(150.00m);

        Assert.Equal(150.00m, wallet.PendingBalance);
        Assert.Equal(0m, wallet.AvailableBalance);
        Assert.Equal(0m, wallet.TotalEarned);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-10)]
    public void AddPendingCashback_NonPositiveAmount_Throws(decimal amount)
    {
        Assert.Throws<ArgumentException>(() => NewWallet().AddPendingCashback(amount));
    }

    [Fact]
    public void ApproveCashback_MovesPendingToAvailableAndTotalEarned()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);

        wallet.ApproveCashback(150.00m);

        Assert.Equal(0m, wallet.PendingBalance);
        Assert.Equal(150.00m, wallet.AvailableBalance);
        Assert.Equal(150.00m, wallet.TotalEarned);
    }

    [Fact]
    public void ApproveCashback_InsufficientPending_Throws()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(100.00m);

        Assert.Throws<InvalidOperationException>(() => wallet.ApproveCashback(150.00m));
    }

    [Fact]
    public void RemovePendingCashback_DebitsPendingOnly()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);

        wallet.RemovePendingCashback(150.00m);

        Assert.Equal(0m, wallet.PendingBalance);
        Assert.Equal(0m, wallet.AvailableBalance);
        Assert.Equal(0m, wallet.TotalEarned);
    }

    [Fact]
    public void RemovePendingCashback_InsufficientPending_Throws()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(100.00m);

        // Balances must never go negative.
        Assert.Throws<InvalidOperationException>(
            () => wallet.RemovePendingCashback(100.01m));
        Assert.Equal(100.00m, wallet.PendingBalance);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    public void RemovePendingCashback_NonPositiveAmount_Throws(decimal amount)
    {
        Assert.Throws<ArgumentException>(() => NewWallet().RemovePendingCashback(amount));
    }

    [Fact]
    public void ReverseConfirmedCashback_DebitsAvailableAndTotalEarned()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);
        wallet.ApproveCashback(150.00m);

        wallet.ReverseConfirmedCashback(150.00m);

        Assert.Equal(0m, wallet.AvailableBalance);
        Assert.Equal(0m, wallet.TotalEarned);
        Assert.Equal(0m, wallet.PendingBalance);
    }

    [Fact]
    public void ReverseConfirmedCashback_InsufficientAvailable_Throws()
    {
        // The user already withdrew — the reversal must fail rather than
        // drive the balance negative.
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);
        wallet.ApproveCashback(150.00m);
        wallet.Withdraw(100.00m);

        Assert.Throws<InvalidOperationException>(
            () => wallet.ReverseConfirmedCashback(150.00m));
        Assert.Equal(50.00m, wallet.AvailableBalance);
        Assert.Equal(150.00m, wallet.TotalEarned);
    }

    [Fact]
    public void ReverseConfirmedCashback_MoneyHeldForWithdrawal_SaysSoAndChangesNothing()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);
        wallet.ApproveCashback(150.00m);
        wallet.HoldForWithdrawal(100.00m);

        var exception = Assert.Throws<InvalidOperationException>(
            () => wallet.ReverseConfirmedCashback(150.00m));

        Assert.Contains("held for a pending withdrawal", exception.Message);
        Assert.Contains("100", exception.Message);
        Assert.Equal(50.00m, wallet.AvailableBalance);
        Assert.Equal(100.00m, wallet.HeldBalance);
        Assert.Equal(150.00m, wallet.TotalEarned);
    }

    [Fact]
    public void ReverseConfirmedCashback_AlreadyWithdrawn_KeepsTheGenericMessage()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);
        wallet.ApproveCashback(150.00m);
        wallet.Withdraw(100.00m);
        wallet.HoldForWithdrawal(10.00m); // held + available (40) still short of 150

        var exception = Assert.Throws<InvalidOperationException>(
            () => wallet.ReverseConfirmedCashback(150.00m));

        Assert.DoesNotContain("held for a pending withdrawal", exception.Message);
    }

    [Fact]
    public void ReverseConfirmedCashback_WorksAgainOnceTheHoldIsReleased()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);
        wallet.ApproveCashback(150.00m);
        wallet.HoldForWithdrawal(100.00m);
        wallet.ReleaseWithdrawalHold(100.00m);

        wallet.ReverseConfirmedCashback(150.00m);

        Assert.Equal(0m, wallet.AvailableBalance);
        Assert.Equal(0m, wallet.TotalEarned);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void ReverseConfirmedCashback_NonPositiveAmount_Throws(decimal amount)
    {
        Assert.Throws<ArgumentException>(
            () => NewWallet().ReverseConfirmedCashback(amount));
    }

    [Fact]
    public void Withdraw_DebitsAvailableAndTracksTotalWithdrawn()
    {
        var wallet = NewWallet();
        wallet.AddPendingCashback(150.00m);
        wallet.ApproveCashback(150.00m);

        wallet.Withdraw(100.00m);

        Assert.Equal(50.00m, wallet.AvailableBalance);
        Assert.Equal(100.00m, wallet.TotalWithdrawn);
    }
}
