using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Payouts;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class WithdrawalWorkerTests
{
    private readonly Mock<IWithdrawalRepository> _withdrawals = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _transactions = new();
    private readonly Mock<IPayoutProvider> _provider = new();
    private readonly Mock<IPayoutDestinationProtector> _protector = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly PayoutPolicy _policy = new(new PayoutOptions
    {
        MaxSubmissionAttempts = 3,
        WorkerIntervalSeconds = 60,
        ReconcileAfterMinutes = 15,
        WorkerBatchSize = 10
    });

    private readonly Wallet _wallet;
    private readonly Withdrawal _withdrawal;

    public WithdrawalWorkerTests()
    {
        Guid userId = Guid.NewGuid();

        _wallet = new Wallet(userId);
        _wallet.AddPendingCashback(1000m);
        _wallet.ApproveCashback(1000m);
        _wallet.HoldForWithdrawal(400m);

        _withdrawal = new Withdrawal(
            userId, _wallet.Id, "WD1", 400m, 4m, 2m,
            PayoutMethod.Upi, "as****@okhdfc", "protected");
        _withdrawal.Approve(null);
        _withdrawal.MarkSubmitted("Test", "P1");

        _provider.SetupGet(p => p.Name).Returns("Test");
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawals.Setup(w => w.GetByIdAsync(_withdrawal.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_withdrawal);
        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
    }

    private WithdrawalProcessor Processor() => new(
        _withdrawals.Object, _provider.Object, _protector.Object,
        new WithdrawalSettlement(_wallets.Object, _transactions.Object),
        _policy, _unitOfWork.Object);

    private void ProviderStatus(PayoutState state) =>
        _provider.Setup(p => p.GetStatusAsync(
                "WD1", "P1", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PayoutStatusResult(state, "P1", "msg", 1m));

    // ---- reconcile -----------------------------------------------------

    [Fact]
    public async Task Reconcile_completes_a_payout_the_provider_says_succeeded()
    {
        ProviderStatus(PayoutState.Succeeded);

        await Processor().ReconcileAsync(_withdrawal.Id, default);

        Assert.Equal(WithdrawalStatus.Completed, _withdrawal.Status);
        Assert.Equal(400m, _wallet.TotalWithdrawn);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Reconcile_fails_and_refunds_a_payout_the_provider_says_failed()
    {
        ProviderStatus(PayoutState.Failed);

        await Processor().ReconcileAsync(_withdrawal.Id, default);

        Assert.Equal(WithdrawalStatus.Failed, _withdrawal.Status);
        Assert.Equal(1000m, _wallet.AvailableBalance);
    }

    [Fact]
    public async Task Reconcile_leaves_a_pending_payout_open_and_touches_it()
    {
        ProviderStatus(PayoutState.Pending);
        DateTime? before = _withdrawal.UpdatedAt;
        await Task.Delay(5);

        await Processor().ReconcileAsync(_withdrawal.Id, default);

        Assert.Equal(WithdrawalStatus.Processing, _withdrawal.Status);
        Assert.True(_withdrawal.UpdatedAt > before);
        Assert.False(_withdrawal.NeedsAttention);
    }

    [Fact]
    public async Task Reconcile_flags_a_payout_the_provider_does_not_know()
    {
        ProviderStatus(PayoutState.Unknown);

        await Processor().ReconcileAsync(_withdrawal.Id, default);

        Assert.True(_withdrawal.NeedsAttention);
        Assert.Equal(WithdrawalStatus.Processing, _withdrawal.Status);
        Assert.Equal(400m, _wallet.HeldBalance);
    }

    [Fact]
    public async Task Reconcile_survives_an_unreachable_provider()
    {
        _provider.Setup(p => p.GetStatusAsync(
                It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("down"));

        await Processor().ReconcileAsync(_withdrawal.Id, default);

        Assert.Equal(WithdrawalStatus.Processing, _withdrawal.Status);
        Assert.Contains("down", _withdrawal.LastError);
        Assert.False(_withdrawal.NeedsAttention);
    }

    [Fact]
    public async Task Reconcile_ignores_withdrawals_that_are_not_processing()
    {
        await Processor().ReconcileAsync(Guid.NewGuid(), default);
        await new WithdrawalSettlement(_wallets.Object, _transactions.Object)
            .CompleteAsync(_withdrawal, "UTR", null, default);
        _unitOfWork.Invocations.Clear();

        await Processor().ReconcileAsync(_withdrawal.Id, default);

        _provider.Verify(p => p.GetStatusAsync(
            It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<CancellationToken>()), Times.Never);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Manual_provider_never_reconciles_or_lists_work()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(false);

        await Processor().ReconcileAsync(_withdrawal.Id, default);
        var work = await Processor().ListPendingAsync(default);

        Assert.Empty(work.ToSubmit);
        Assert.Empty(work.ToReconcile);
        _withdrawals.Verify(w => w.GetByIdAsync(
            It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    // ---- listing -------------------------------------------------------

    [Fact]
    public async Task ListPending_asks_for_the_right_slices_and_returns_only_ids()
    {
        Guid toSubmit = Guid.NewGuid();

        _withdrawals.Setup(w => w.ListIdsByStatusAsync(
                WithdrawalStatus.Approved, It.IsAny<DateTime?>(), 10, 3, false,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { toSubmit });
        _withdrawals.Setup(w => w.ListIdsByStatusAsync(
                WithdrawalStatus.Processing, It.IsAny<DateTime?>(), 10, null, null,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { _withdrawal.Id });

        var work = await Processor().ListPendingAsync(default);

        Assert.Equal(new[] { toSubmit }, work.ToSubmit);
        Assert.Equal(new[] { _withdrawal.Id }, work.ToReconcile);

        // Not picked up until idle for a full worker interval / reconcile window.
        _withdrawals.Verify(w => w.ListIdsByStatusAsync(
            WithdrawalStatus.Approved,
            It.Is<DateTime?>(d => d < DateTime.UtcNow.AddSeconds(-55)),
            10, 3, false, It.IsAny<CancellationToken>()), Times.Once);
        _withdrawals.Verify(w => w.ListIdsByStatusAsync(
            WithdrawalStatus.Processing,
            It.Is<DateTime?>(d => d < DateTime.UtcNow.AddMinutes(-14)),
            10, null, null, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ListPending_never_loads_whole_withdrawals()
    {
        await Processor().ListPendingAsync(default);

        // Ids come straight from the projection; no row (and so no encrypted
        // destination) is materialised just to read an id.
        _withdrawals.Verify(w => w.GetByIdAsync(
            It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Submit_skips_a_flagged_withdrawal()
    {
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(PayoutSubmissionResult.Accepted("P"));
        var flagged = new Withdrawal(
            Guid.NewGuid(), _wallet.Id, "WD3", 300m, 0m, 0m,
            PayoutMethod.Upi, "x****@upi", "protected");
        flagged.Approve(null);
        flagged.FlagNeedsAttention("waiting for a person");
        _withdrawals.Setup(w => w.GetByIdAsync(flagged.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(flagged);

        await Processor().SubmitAsync(flagged.Id, default);

        _provider.Verify(p => p.SubmitAsync(
            It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()), Times.Never);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }


    // ---- worker --------------------------------------------------------

    private static (WithdrawalWorker Worker, ScopeCounter Scopes) BuildWorker(
        Mock<IWithdrawalProcessor> processor,
        bool automatic)
    {
        var provider = new Mock<IPayoutProvider>();
        provider.SetupGet(p => p.Name).Returns("Test");
        provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(automatic);

        var services = new ServiceCollection();
        services.AddScoped(_ => processor.Object);
        var root = services.BuildServiceProvider();

        var counter = new ScopeCounter(root.GetRequiredService<IServiceScopeFactory>());

        var worker = new WithdrawalWorker(
            counter, provider.Object,
            new PayoutPolicy(new PayoutOptions()),
            NullLogger<WithdrawalWorker>.Instance);

        return (worker, counter);
    }

    private sealed class ScopeCounter : IServiceScopeFactory
    {
        private readonly IServiceScopeFactory _inner;

        public int Count { get; private set; }

        public ScopeCounter(IServiceScopeFactory inner) => _inner = inner;

        public IServiceScope CreateScope()
        {
            Count++;
            return _inner.CreateScope();
        }
    }

    [Fact]
    public async Task Worker_processes_each_item_in_its_own_scope_and_survives_a_failure()
    {
        Guid bad = Guid.NewGuid(), good = Guid.NewGuid(), slow = Guid.NewGuid();
        var processor = new Mock<IWithdrawalProcessor>();
        processor.Setup(p => p.ListPendingAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(new WithdrawalWorkList(new[] { bad, good }, new[] { slow }));
        processor.Setup(p => p.SubmitAsync(bad, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("boom"));

        var (worker, scopes) = BuildWorker(processor, automatic: true);
        await worker.RunOnceAsync(default);

        processor.Verify(p => p.SubmitAsync(good, It.IsAny<CancellationToken>()), Times.Once);
        processor.Verify(p => p.ReconcileAsync(slow, It.IsAny<CancellationToken>()), Times.Once);
        // one scope to list + one per item
        Assert.Equal(4, scopes.Count);
    }

    [Fact]
    public async Task Worker_does_nothing_for_the_manual_provider()
    {
        var processor = new Mock<IWithdrawalProcessor>();
        var (worker, _) = BuildWorker(processor, automatic: false);

        await worker.StartAsync(default);
        await worker.StopAsync(default);

        processor.Verify(p => p.ListPendingAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
