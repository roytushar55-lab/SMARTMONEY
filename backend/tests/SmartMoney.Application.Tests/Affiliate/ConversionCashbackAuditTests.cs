using Moq;
using SmartMoney.Application.Abstractions.CashbackRates;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Affiliate;

/// <summary>
/// What the ingestion pipeline writes into a cashback's audit trail: a
/// Created line, a line for each change in what the network says, and a
/// FlaggedForReview line. None of them has an actor: the network is not an admin.
/// </summary>
public sealed class ConversionCashbackAuditTests
{
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<ICashbackRateResolver> _rateResolver = new();
    private readonly Mock<IStoreRepository> _stores = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IAffiliateClickRepository> _clicks = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<ICashbackEventRepository> _events = new();
    private readonly List<CashbackEvent> _recorded = new();

    private readonly Guid _clickId = Guid.NewGuid();
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _storeId = Guid.NewGuid();
    private readonly Guid _networkId = Guid.NewGuid();

    public ConversionCashbackAuditTests()
    {
        _rateResolver.Setup(r => r.ResolveEffectiveRateAsync(
                It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new EffectiveCashbackRate(60.00m, 60, CashbackRateSource.SystemGlobal));
        _stores.Setup(s => s.GetPrimaryCategoryIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((Guid?)null);
        _clicks.Setup(c => c.GetByIdAsync(_clickId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new AffiliateClick { Id = _clickId, UserId = _userId, StoreId = _storeId, AffiliateNetworkId = _networkId });
        _wallets.Setup(w => w.GetByUserIdAsync(_userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Wallet(_userId));
        _users.Setup(u => u.GetByIdAsync(_userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new User("Test User", "test@example.com", "9876543210", "hash", Guid.NewGuid()));
        _events.Setup(e => e.AddAsync(It.IsAny<CashbackEvent>(), It.IsAny<CancellationToken>()))
            .Callback<CashbackEvent, CancellationToken>((e, _) => _recorded.Add(e))
            .Returns(Task.CompletedTask);
    }

    private ConversionCashbackProcessor Processor() =>
        new(_cashbacks.Object, _rateResolver.Object, _stores.Object, _wallets.Object,
            _clicks.Object, _walletTransactions.Object, _users.Object, _events.Object);

    private AffiliateConversion Conversion(string status) => new()
    {
        AffiliateNetworkId = _networkId,
        AffiliateClickId = _clickId,
        NetworkTransactionId = "TXN-1",
        NetworkStatus = status,
        CommissionAmount = 250.00m,
    };

    private Cashback ExistingCashback(AffiliateConversion conversion)
    {
        var cashback = new Cashback(_userId, Guid.NewGuid(), conversion.Id, 150.00m, DateTime.UtcNow.AddDays(30));
        _cashbacks.Setup(c => c.GetByConversionIdAsync(conversion.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(cashback);
        return cashback;
    }

    [Fact]
    public async Task FirstPendingReport_RecordsCreated_WithNoActor()
    {
        await Processor().ProcessAsync(Conversion("pending"), CancellationToken.None);

        var e = Assert.Single(_recorded);
        Assert.Equal(CashbackEventType.Created, e.Type);
        Assert.Null(e.ActorUserId);
        Assert.Null(e.FromStatus);
        Assert.Equal(CashbackStatus.Pending, e.ToStatus);
        Assert.Equal(150.00m, e.Amount);
        Assert.Equal("pending", e.NetworkStatus);
    }

    [Fact]
    public async Task FirstReportIsValidated_RecordsCreatedThenFlagged_AndNoStatusChange()
    {
        // A new conversion has no previous status, so its first report is
        // covered by Created and must not also appear as a "change".
        await Processor().ProcessAsync(Conversion("validated"), CancellationToken.None);

        Assert.Equal(
            new[] { CashbackEventType.Created, CashbackEventType.FlaggedForReview },
            _recorded.Select(e => e.Type).ToArray());
        var flagged = _recorded[1];
        Assert.Equal(CashbackStatus.Pending, flagged.FromStatus);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, flagged.ToStatus);
        Assert.Equal("validated", flagged.NetworkStatus);
        Assert.All(_recorded, e => Assert.Null(e.ActorUserId));
    }

    [Fact]
    public async Task PendingThenValidated_RecordsTheChangeAndTheFlag()
    {
        var conversion = Conversion("validated");
        ExistingCashback(conversion);

        await Processor().ProcessAsync(conversion, CancellationToken.None, previousNetworkStatus: "pending");

        Assert.Equal(
            new[] { CashbackEventType.NetworkStatusChanged, CashbackEventType.FlaggedForReview },
            _recorded.Select(e => e.Type).ToArray());
        Assert.Equal(CashbackStatus.Pending, _recorded[0].FromStatus);
        Assert.Equal("validated", _recorded[0].NetworkStatus);
    }

    [Fact]
    public async Task AReplayOfTheSameStatus_RecordsNothing()
    {
        var conversion = Conversion("pending");
        ExistingCashback(conversion);

        await Processor().ProcessAsync(conversion, CancellationToken.None, previousNetworkStatus: "pending");

        Assert.Empty(_recorded);
    }

    [Fact]
    public async Task TheSameStatusInADifferentCase_IsNotAChange()
    {
        var conversion = Conversion("Pending");
        ExistingCashback(conversion);

        await Processor().ProcessAsync(conversion, CancellationToken.None, previousNetworkStatus: "pending");

        Assert.Empty(_recorded);
    }

    [Fact]
    public async Task PaidAfterValidated_IsRecordedButMovesNothing()
    {
        var conversion = Conversion("paid");
        var cashback = ExistingCashback(conversion);
        cashback.FlagForReview();

        await Processor().ProcessAsync(conversion, CancellationToken.None, previousNetworkStatus: "validated");

        var e = Assert.Single(_recorded);
        Assert.Equal(CashbackEventType.NetworkStatusChanged, e.Type);
        Assert.Equal("paid", e.NetworkStatus);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, cashback.Status);
    }

    [Fact]
    public async Task AnUnattributedConversion_RecordsNothing()
    {
        var conversion = Conversion("pending");
        conversion.AffiliateClickId = null;

        await Processor().ProcessAsync(conversion, CancellationToken.None, previousNetworkStatus: "validated");

        Assert.Empty(_recorded);
    }

    [Fact]
    public async Task ReversedAfterConfirmation_RecordsTheChangeAndTheFlag()
    {
        var conversion = Conversion("reversed");
        var cashback = ExistingCashback(conversion);
        cashback.Confirm();

        await Processor().ProcessAsync(conversion, CancellationToken.None, previousNetworkStatus: "validated");

        Assert.Equal(
            new[] { CashbackEventType.NetworkStatusChanged, CashbackEventType.FlaggedForReview },
            _recorded.Select(e => e.Type).ToArray());
        Assert.Equal(CashbackStatus.Confirmed, _recorded[1].FromStatus);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, _recorded[1].ToStatus);
    }
}
