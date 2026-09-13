using Moq;
using SmartMoney.Application.Abstractions.CashbackRates;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Affiliate;

public sealed class ConversionCashbackProcessorTests
{
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<ICashbackRateResolver> _rateResolver = new();
    private readonly Mock<IStoreRepository> _stores = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IAffiliateClickRepository> _clicks = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();

    private readonly Guid _clickId = Guid.NewGuid();
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _storeId = Guid.NewGuid();
    private readonly Guid _networkId = Guid.NewGuid();

    private ConversionCashbackProcessor CreateProcessor()
    {
        return new ConversionCashbackProcessor(
            _cashbacks.Object, _rateResolver.Object, _stores.Object, _wallets.Object,
            _clicks.Object, _walletTransactions.Object);
    }

    private AffiliateConversion NewConversion(
        string status,
        decimal? commission = 250.00m,
        bool attributed = true)
    {
        return new AffiliateConversion
        {
            AffiliateNetworkId = _networkId,
            AffiliateClickId = attributed ? _clickId : null,
            NetworkTransactionId = "TXN-1",
            NetworkStatus = status,
            CommissionAmount = commission,
        };
    }

    private void SetupHappyDependencies(
        decimal sharePercent = 60.00m,
        Wallet? existingWallet = null)
    {
        _rateResolver.Setup(r => r.ResolveEffectiveRateAsync(
                It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new EffectiveCashbackRate(sharePercent, 60, CashbackRateSource.SystemGlobal));

        _stores.Setup(s => s.GetPrimaryCategoryIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((Guid?)null);

        _clicks.Setup(c => c.GetByIdAsync(_clickId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new AffiliateClick
            {
                Id = _clickId,
                UserId = _userId,
                StoreId = _storeId,
                AffiliateNetworkId = _networkId
            });

        _wallets.Setup(w => w.GetByUserIdAsync(_userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingWallet);
    }

    [Fact]
    public async Task Pending_Attributed_CreatesPendingCashbackWithSharedAmount()
    {
        SetupHappyDependencies();
        Cashback? created = null;
        _cashbacks.Setup(c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()))
            .Callback<Cashback, CancellationToken>((cb, _) => created = cb);

        await CreateProcessor().ProcessAsync(NewConversion("pending"), CancellationToken.None);

        Assert.NotNull(created);
        Assert.Equal(CashbackStatus.Pending, created!.Status);
        Assert.Equal(150.00m, created.CashbackAmount); // 250 x 60%
        Assert.Equal(_userId, created.UserId);
    }

    [Fact]
    public async Task Pending_ExistingWallet_CreditsPendingBalanceWithLedgerEntry()
    {
        var wallet = new Wallet(_userId);
        SetupHappyDependencies(existingWallet: wallet);
        WalletTransaction? entry = null;
        _walletTransactions.Setup(t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()))
            .Callback<WalletTransaction, CancellationToken>((tx, _) => entry = tx);

        await CreateProcessor().ProcessAsync(NewConversion("pending"), CancellationToken.None);

        Assert.Equal(150.00m, wallet.PendingBalance);
        Assert.Equal(0m, wallet.AvailableBalance);
        Assert.NotNull(entry);
        Assert.Equal(WalletTransactionType.CashbackPending, entry!.Type);
        Assert.Equal(150.00m, entry.Amount);
        Assert.Equal(_userId, entry.UserId);
        // Snapshots are taken AFTER the mutation.
        Assert.Equal(150.00m, entry.PendingBalanceAfter);
        Assert.Equal(0m, entry.AvailableBalanceAfter);
    }

    // MVP safety rule: automated code may only ever land a cashback on
    // Pending or AwaitingAdminReview. It must NEVER call Confirm/Reject/
    // Reverse directly — those are admin-only actions (the admin cashback
    // endpoints). Every "decisive status" test below asserts
    // AwaitingAdminReview, not the terminal status the network reported.

    [Fact]
    public async Task Validated_WithoutPriorCashback_CreatesAndFlagsForReview()
    {
        SetupHappyDependencies();
        Cashback? created = null;
        _cashbacks.Setup(c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()))
            .Callback<Cashback, CancellationToken>((cb, _) => created = cb);

        await CreateProcessor().ProcessAsync(NewConversion("validated"), CancellationToken.None);

        Assert.NotNull(created);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, created!.Status);
    }

    [Fact]
    public async Task Validated_WithExistingPendingCashback_FlagsForReview()
    {
        var existing = ExistingCashback();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateProcessor().ProcessAsync(NewConversion("validated"), CancellationToken.None);

        Assert.Equal(CashbackStatus.AwaitingAdminReview, existing.Status);
        _cashbacks.Verify(
            c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()),
            Times.Never);
        // Flag-only path: the pending credit happened at creation time, so no
        // wallet mutation and no ledger entry now.
        _walletTransactions.Verify(
            t => t.AddAsync(It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task NetworkPaid_NeverBecomesPaidOut()
    {
        // THE critical business rule: the network's "paid" means the network
        // was paid by the advertiser, not that Smart Money paid the user.
        // It doesn't even queue a review — it's simply not a decisive status.
        var existing = ExistingCashback();
        existing.Confirm();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateProcessor().ProcessAsync(NewConversion("paid"), CancellationToken.None);

        Assert.Equal(CashbackStatus.Confirmed, existing.Status);
    }

    [Fact]
    public async Task Rejected_OnPendingCashback_FlagsForReview()
    {
        var existing = ExistingCashback();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateProcessor().ProcessAsync(NewConversion("rejected"), CancellationToken.None);

        Assert.Equal(CashbackStatus.AwaitingAdminReview, existing.Status);
    }

    [Fact]
    public async Task Reversed_OnConfirmedCashback_FlagsForReview()
    {
        var existing = ExistingCashback();
        existing.Confirm();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateProcessor().ProcessAsync(NewConversion("reversed"), CancellationToken.None);

        Assert.Equal(CashbackStatus.AwaitingAdminReview, existing.Status);
        // The admin still needs to be able to actually reverse it afterward.
        existing.Reverse();
        Assert.Equal(CashbackStatus.Reversed, existing.Status);
    }

    [Fact]
    public async Task Reversed_OnPendingCashback_FlagsForReview()
    {
        var existing = ExistingCashback();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateProcessor().ProcessAsync(NewConversion("reversed"), CancellationToken.None);

        Assert.Equal(CashbackStatus.AwaitingAdminReview, existing.Status);
    }

    [Fact]
    public async Task AlreadyAwaitingReview_AnotherDecisiveStatus_StaysUntouched()
    {
        // Duplicate/out-of-order postbacks (e.g. "validated" replayed after an
        // admin already resolved it, or two decisive statuses arriving close
        // together) must never throw and must never re-trigger a transition.
        var existing = ExistingCashback();
        existing.FlagForReview();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateProcessor().ProcessAsync(NewConversion("validated"), CancellationToken.None);

        Assert.Equal(CashbackStatus.AwaitingAdminReview, existing.Status);
    }

    [Fact]
    public async Task AlreadyRejected_DecisiveStatusArrives_StaysRejected()
    {
        // A terminal outcome an admin already decided must not be reopened by
        // a later network postback.
        var existing = ExistingCashback();
        existing.Reject();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateProcessor().ProcessAsync(NewConversion("reversed"), CancellationToken.None);

        Assert.Equal(CashbackStatus.Rejected, existing.Status);
    }

    [Fact]
    public async Task UnattributedConversion_CreatesNothing()
    {
        await CreateProcessor().ProcessAsync(
            NewConversion("validated", attributed: false), CancellationToken.None);

        _cashbacks.Verify(
            c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()),
            Times.Never);
        _cashbacks.Verify(
            c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task MissingCommission_CreatesNothing()
    {
        SetupHappyDependencies();

        await CreateProcessor().ProcessAsync(
            NewConversion("pending", commission: null), CancellationToken.None);

        _cashbacks.Verify(
            c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ExistingCashback_IsNeverDuplicated()
    {
        SetupHappyDependencies();
        _cashbacks.Setup(c => c.GetByConversionIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(ExistingCashback());

        await CreateProcessor().ProcessAsync(NewConversion("pending"), CancellationToken.None);

        _cashbacks.Verify(
            c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task MissingWallet_IsCreatedAndCreditedWithPendingCashback()
    {
        SetupHappyDependencies(existingWallet: null);
        Wallet? createdWallet = null;
        _wallets.Setup(w => w.AddAsync(It.IsAny<Wallet>(), It.IsAny<CancellationToken>()))
            .Callback<Wallet, CancellationToken>((w, _) => createdWallet = w);

        await CreateProcessor().ProcessAsync(NewConversion("pending"), CancellationToken.None);

        Assert.NotNull(createdWallet);
        Assert.Equal(_userId, createdWallet!.UserId);
        Assert.Equal(150.00m, createdWallet.PendingBalance);
        Assert.Equal(0m, createdWallet.AvailableBalance);
        _walletTransactions.Verify(
            t => t.AddAsync(
                It.Is<WalletTransaction>(tx =>
                    tx.Type == WalletTransactionType.CashbackPending
                    && tx.Amount == 150.00m),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Theory]
    [InlineData(100.01, 60.00, 60.01)]  // 60.006 rounds away from zero
    [InlineData(0.01, 60.00, 0.01)]     // 0.006 -> 0.01, still positive
    [InlineData(333.33, 50.00, 166.67)] // 166.665 midpoint away from zero
    public async Task CashbackAmount_RoundsToTwoDecimalsAwayFromZero(
        decimal commission, decimal share, decimal expected)
    {
        SetupHappyDependencies(sharePercent: share);
        Cashback? created = null;
        _cashbacks.Setup(c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()))
            .Callback<Cashback, CancellationToken>((cb, _) => created = cb);

        await CreateProcessor().ProcessAsync(
            NewConversion("pending", commission: commission), CancellationToken.None);

        Assert.NotNull(created);
        Assert.Equal(expected, created!.CashbackAmount);
    }

    private static Cashback ExistingCashback()
    {
        return new Cashback(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            100.00m, DateTime.UtcNow.AddDays(60));
    }
}
