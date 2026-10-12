using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Domain;

public sealed class WalletHoldTests
{
    private static Wallet FundedWallet(decimal amount = 1000m)
    {
        var wallet = new Wallet(Guid.NewGuid());
        wallet.AddPendingCashback(amount);
        wallet.ApproveCashback(amount);
        return wallet;
    }

    [Fact]
    public void Hold_moves_available_to_held_without_touching_totals()
    {
        var wallet = FundedWallet();

        wallet.HoldForWithdrawal(400m);

        Assert.Equal(600m, wallet.AvailableBalance);
        Assert.Equal(400m, wallet.HeldBalance);
        Assert.Equal(0m, wallet.TotalWithdrawn);
        Assert.Equal(1000m, wallet.TotalEarned);
    }

    [Fact]
    public void Hold_more_than_available_throws_and_changes_nothing()
    {
        var wallet = FundedWallet(100m);

        Assert.Throws<InvalidOperationException>(() => wallet.HoldForWithdrawal(100.01m));

        Assert.Equal(100m, wallet.AvailableBalance);
        Assert.Equal(0m, wallet.HeldBalance);
    }

    [Fact]
    public void Held_money_cannot_be_held_twice()
    {
        var wallet = FundedWallet(500m);
        wallet.HoldForWithdrawal(500m);

        Assert.Throws<InvalidOperationException>(() => wallet.HoldForWithdrawal(1m));
    }

    [Fact]
    public void Complete_spends_held_money_into_total_withdrawn()
    {
        var wallet = FundedWallet();
        wallet.HoldForWithdrawal(400m);

        wallet.CompleteWithdrawal(400m);

        Assert.Equal(0m, wallet.HeldBalance);
        Assert.Equal(600m, wallet.AvailableBalance);
        Assert.Equal(400m, wallet.TotalWithdrawn);
    }

    [Fact]
    public void Release_returns_held_money_to_available()
    {
        var wallet = FundedWallet();
        wallet.HoldForWithdrawal(400m);

        wallet.ReleaseWithdrawalHold(400m);

        Assert.Equal(0m, wallet.HeldBalance);
        Assert.Equal(1000m, wallet.AvailableBalance);
        Assert.Equal(0m, wallet.TotalWithdrawn);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void Complete_or_release_more_than_held_throws(bool complete)
    {
        var wallet = FundedWallet();
        wallet.HoldForWithdrawal(100m);

        Assert.Throws<InvalidOperationException>(() =>
        {
            if (complete)
                wallet.CompleteWithdrawal(100.01m);
            else
                wallet.ReleaseWithdrawalHold(100.01m);
        });

        Assert.Equal(100m, wallet.HeldBalance);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    public void Non_positive_amounts_are_refused(decimal amount)
    {
        var wallet = FundedWallet();
        wallet.HoldForWithdrawal(100m);

        Assert.Throws<ArgumentException>(() => wallet.HoldForWithdrawal(amount));
        Assert.Throws<ArgumentException>(() => wallet.CompleteWithdrawal(amount));
        Assert.Throws<ArgumentException>(() => wallet.ReleaseWithdrawalHold(amount));
    }

    [Fact]
    public void Ledger_entry_records_the_held_balance_and_withdrawal()
    {
        var wallet = FundedWallet();
        wallet.HoldForWithdrawal(400m);
        Guid withdrawalId = Guid.NewGuid();

        var entry = new WalletTransaction(
            wallet.Id, wallet.UserId, WalletTransactionType.WithdrawalRequested,
            400m, null, "x", wallet.AvailableBalance, wallet.PendingBalance,
            wallet.HeldBalance, withdrawalId);

        Assert.Equal(400m, entry.HeldBalanceAfter);
        Assert.Equal(withdrawalId, entry.WithdrawalId);
    }

    [Fact]
    public void Older_callers_default_the_new_ledger_fields()
    {
        var entry = new WalletTransaction(
            Guid.NewGuid(), Guid.NewGuid(), WalletTransactionType.CashbackPending,
            10m, null, null, 0m, 10m);

        Assert.Equal(0m, entry.HeldBalanceAfter);
        Assert.Null(entry.WithdrawalId);
    }
}
