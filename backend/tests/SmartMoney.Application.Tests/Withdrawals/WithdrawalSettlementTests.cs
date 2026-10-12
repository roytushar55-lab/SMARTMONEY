using Moq;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class WithdrawalSettlementTests
{
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _transactions = new();
    private readonly List<WalletTransaction> _entries = new();
    private readonly Wallet _wallet;
    private readonly Withdrawal _withdrawal;

    public WithdrawalSettlementTests()
    {
        Guid userId = Guid.NewGuid();

        _wallet = new Wallet(userId);
        _wallet.AddPendingCashback(1000m);
        _wallet.ApproveCashback(1000m);
        _wallet.HoldForWithdrawal(400m);

        _withdrawal = new Withdrawal(
            userId, _wallet.Id, "WD1", 400m, 10m, 5m,
            PayoutMethod.Upi, "ab****@upi", "protected");

        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
        _transactions.Setup(t => t.AddAsync(
                It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()))
            .Callback<WalletTransaction, CancellationToken>((tx, _) => _entries.Add(tx));
    }

    private WithdrawalSettlement Create() =>
        new(_wallets.Object, _transactions.Object);

    private async Task Approve()
    {
        _withdrawal.Approve(null);
        await Task.CompletedTask;
    }

    [Fact]
    public async Task Complete_moves_held_to_withdrawn_and_writes_one_entry()
    {
        await Approve();

        await Create().CompleteAsync(_withdrawal, "UTR123", null, default);

        Assert.Equal(WithdrawalStatus.Completed, _withdrawal.Status);
        Assert.Equal(0m, _wallet.HeldBalance);
        Assert.Equal(600m, _wallet.AvailableBalance);
        Assert.Equal(400m, _wallet.TotalWithdrawn);
        Assert.Null(_withdrawal.DestinationProtected);

        WalletTransaction entry = Assert.Single(_entries);
        Assert.Equal(WalletTransactionType.WithdrawalCompleted, entry.Type);
        Assert.Equal(400m, entry.Amount);
        Assert.Equal(0m, entry.HeldBalanceAfter);
        Assert.Equal(_withdrawal.Id, entry.WithdrawalId);
    }

    [Fact]
    public async Task Cancel_returns_held_money()
    {
        await Create().CancelAsync(_withdrawal, default);

        Assert.Equal(WithdrawalStatus.Cancelled, _withdrawal.Status);
        Assert.Equal(1000m, _wallet.AvailableBalance);
        Assert.Equal(0m, _wallet.HeldBalance);
        Assert.Equal(WalletTransactionType.WithdrawalReleased, Assert.Single(_entries).Type);
    }

    [Fact]
    public async Task Reject_returns_held_money_and_keeps_the_reason()
    {
        await Create().RejectAsync(_withdrawal, Guid.NewGuid(), "Name mismatch", default);

        Assert.Equal(WithdrawalStatus.Rejected, _withdrawal.Status);
        Assert.Equal("Name mismatch", _withdrawal.FailureReason);
        Assert.Equal(1000m, _wallet.AvailableBalance);
    }

    [Fact]
    public async Task Cancel_after_approval_is_refused_and_changes_nothing()
    {
        await Approve();

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => Create().CancelAsync(_withdrawal, default));

        Assert.Equal(400m, _wallet.HeldBalance);
        Assert.Empty(_entries);
    }

    [Fact]
    public async Task Provider_success_completes_once_and_is_idempotent()
    {
        await Approve();
        var settlement = Create();

        var first = await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Succeeded, "P1", null, 2m, default);
        var second = await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Succeeded, "P1", null, 2m, default);

        Assert.Equal(SettlementOutcome.Applied, first);
        Assert.Equal(SettlementOutcome.Duplicate, second);
        Assert.Single(_entries);
        Assert.Equal(400m, _wallet.TotalWithdrawn);
        Assert.Equal(2m, _withdrawal.ActualProviderFee);
    }

    [Theory]
    [InlineData(PayoutState.Succeeded, WithdrawalStatus.Completed)]
    [InlineData(PayoutState.Failed, WithdrawalStatus.Failed)]
    public async Task A_provider_result_that_resolves_a_flagged_withdrawal_clears_the_flag(
        PayoutState state, WithdrawalStatus expected)
    {
        await Approve();
        _withdrawal.MarkSubmitted("Test", "P1");
        _withdrawal.FlagNeedsAttention("provider does not recognise this payout");

        await Create().ApplyProviderStateAsync(
            _withdrawal, state, "P1", null, null, default);

        Assert.Equal(expected, _withdrawal.Status);
        Assert.False(_withdrawal.NeedsAttention);
    }

    [Fact]
    public async Task A_contradiction_after_settling_flags_it_again()
    {
        await Approve();
        _withdrawal.FlagNeedsAttention("old problem");
        var settlement = Create();
        await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Failed, null, null, null, default);
        Assert.False(_withdrawal.NeedsAttention);

        await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Succeeded, "P1", null, null, default);

        Assert.True(_withdrawal.NeedsAttention);
    }

    [Fact]
    public async Task Provider_failure_releases_money_with_a_plain_reason()
    {
        await Approve();

        var outcome = await Create().ApplyProviderStateAsync(
            _withdrawal, PayoutState.Failed, null, "BENE_BANK_DOWN raw text", null, default);

        Assert.Equal(SettlementOutcome.Applied, outcome);
        Assert.Equal(WithdrawalStatus.Failed, _withdrawal.Status);
        Assert.Equal(WithdrawalSettlement.DefaultFailureReason, _withdrawal.FailureReason);
        Assert.Equal("BENE_BANK_DOWN raw text", _withdrawal.LastError);
        Assert.Equal(1000m, _wallet.AvailableBalance);
    }

    [Fact]
    public async Task Success_after_recorded_failure_is_flagged_and_never_paid_twice()
    {
        await Approve();
        var settlement = Create();
        await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Failed, null, null, null, default);
        _entries.Clear();

        var outcome = await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Succeeded, "P1", null, null, default);

        Assert.Equal(SettlementOutcome.NeedsAttention, outcome);
        Assert.True(_withdrawal.NeedsAttention);
        Assert.Equal(WithdrawalStatus.Failed, _withdrawal.Status);
        Assert.Equal(0m, _wallet.TotalWithdrawn);
        Assert.Empty(_entries);
    }

    [Fact]
    public async Task Repeated_contradictions_flag_once()
    {
        await Approve();
        var settlement = Create();
        await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Failed, null, null, null, default);

        await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Succeeded, "P1", null, null, default);
        string? noteAfterFirst = _withdrawal.ReviewNote;
        await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Succeeded, "P1", null, null, default);

        Assert.Equal(noteAfterFirst, _withdrawal.ReviewNote);
    }

    [Fact]
    public async Task Failure_after_success_is_flagged_and_money_stays_withdrawn()
    {
        await Approve();
        var settlement = Create();
        await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Succeeded, "P1", null, null, default);

        var outcome = await settlement.ApplyProviderStateAsync(
            _withdrawal, PayoutState.Failed, null, null, null, default);

        Assert.Equal(SettlementOutcome.NeedsAttention, outcome);
        Assert.Equal(WithdrawalStatus.Completed, _withdrawal.Status);
        Assert.Equal(400m, _wallet.TotalWithdrawn);
    }

    [Theory]
    [InlineData(PayoutState.Pending)]
    [InlineData(PayoutState.Unknown)]
    public async Task Pending_and_unknown_change_nothing(PayoutState state)
    {
        await Approve();

        var outcome = await Create().ApplyProviderStateAsync(
            _withdrawal, state, null, null, null, default);

        Assert.Equal(SettlementOutcome.Ignored, outcome);
        Assert.Equal(WithdrawalStatus.Approved, _withdrawal.Status);
        Assert.Empty(_entries);
    }
}
