using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks.ApproveCashback;
using SmartMoney.Application.Features.Cashbacks.GetCashbackEvents;
using SmartMoney.Application.Features.Cashbacks.RejectCashback;
using SmartMoney.Application.Features.Cashbacks.ReverseCashback;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Cashbacks;

public sealed class CashbackAuditTrailTests
{
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();
    private readonly Mock<ICashbackEventRepository> _events = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _reviewerId = Guid.NewGuid();
    private readonly Wallet _wallet;
    private readonly List<CashbackEvent> _recorded = new();

    public CashbackAuditTrailTests()
    {
        _wallet = new Wallet(_userId);
        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
        _events.Setup(e => e.AddAsync(It.IsAny<CashbackEvent>(), It.IsAny<CancellationToken>()))
            .Callback<CashbackEvent, CancellationToken>((e, _) => _recorded.Add(e))
            .Returns(Task.CompletedTask);
    }

    private Cashback NewCashback(decimal amount = 150.00m, string? networkStatus = "validated")
    {
        var cashback = new Cashback(
            _userId, _wallet.Id, Guid.NewGuid(), amount, DateTime.UtcNow.AddDays(30));
        _wallet.AddPendingCashback(amount);

        if (networkStatus is not null)
        {
            // The conversion rides along on a loaded cashback; the entity has
            // no public setter for the navigation, so set it the way EF does.
            typeof(Cashback).GetProperty(nameof(Cashback.AffiliateConversion))!
                .SetValue(cashback, new AffiliateConversion { NetworkStatus = networkStatus });
        }

        _cashbacks.Setup(c => c.GetByIdAsync(cashback.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(cashback);
        return cashback;
    }

    private ApproveCashbackCommandHandler Approver() =>
        new(_cashbacks.Object, _wallets.Object, _walletTransactions.Object, _events.Object, _unitOfWork.Object);

    private RejectCashbackCommandHandler Rejecter() =>
        new(_cashbacks.Object, _wallets.Object, _walletTransactions.Object, _events.Object, _unitOfWork.Object);

    private ReverseCashbackCommandHandler Reverser() =>
        new(_cashbacks.Object, _wallets.Object, _walletTransactions.Object, _events.Object, _unitOfWork.Object);

    // ---- the entity

    [Fact]
    public void Event_TrimsTheReason_AndTurnsBlankIntoNull()
    {
        var withReason = new CashbackEvent(
            Guid.NewGuid(), CashbackEventType.Approved, _reviewerId,
            CashbackStatus.Pending, CashbackStatus.Confirmed, 10m, "  validated ", "  checked with the merchant  ");
        var blank = new CashbackEvent(
            Guid.NewGuid(), CashbackEventType.Approved, _reviewerId,
            CashbackStatus.Pending, CashbackStatus.Confirmed, 10m, null, "   ");

        Assert.Equal("checked with the merchant", withReason.Reason);
        Assert.Equal("validated", withReason.NetworkStatus);
        Assert.Null(blank.Reason);
    }

    [Fact]
    public void Event_RefusesAReasonLongerThanTheLimit()
    {
        var tooLong = new string('x', CashbackEvent.MaxReasonLength + 1);

        Assert.Throws<ArgumentException>(() => new CashbackEvent(
            Guid.NewGuid(), CashbackEventType.Rejected, _reviewerId,
            CashbackStatus.Pending, CashbackStatus.Rejected, 10m, null, tooLong));

        // Exactly at the limit is fine.
        var atLimit = new CashbackEvent(
            Guid.NewGuid(), CashbackEventType.Rejected, _reviewerId,
            CashbackStatus.Pending, CashbackStatus.Rejected, 10m, null, new string('x', CashbackEvent.MaxReasonLength));
        Assert.Equal(CashbackEvent.MaxReasonLength, atLimit.Reason!.Length);
    }

    [Fact]
    public void Event_RequiresACashback()
    {
        Assert.Throws<ArgumentException>(() => new CashbackEvent(
            Guid.Empty, CashbackEventType.Created, null, null, CashbackStatus.Pending, 10m, "pending", null));
    }

    // ---- decisions record who, why, from, to and the network status

    [Fact]
    public async Task Approve_RecordsTheReviewerTheReasonAndBothStatuses()
    {
        var cashback = NewCashback(150m, "validated");
        cashback.FlagForReview();

        await Approver().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId, "Merchant confirmed the order"),
            CancellationToken.None);

        var e = Assert.Single(_recorded);
        Assert.Equal(CashbackEventType.Approved, e.Type);
        Assert.Equal(cashback.Id, e.CashbackId);
        Assert.Equal(_reviewerId, e.ActorUserId);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, e.FromStatus);
        Assert.Equal(CashbackStatus.Confirmed, e.ToStatus);
        Assert.Equal(150m, e.Amount);
        Assert.Equal("validated", e.NetworkStatus);
        Assert.Equal("Merchant confirmed the order", e.Reason);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Approve_WithoutAReason_StillRecordsTheReviewer()
    {
        var cashback = NewCashback();

        await Approver().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None);

        var e = Assert.Single(_recorded);
        Assert.Equal(_reviewerId, e.ActorUserId);
        Assert.Null(e.Reason);
        Assert.Equal(CashbackStatus.Pending, e.FromStatus);
    }

    [Fact]
    public async Task Reject_RecordsTheReviewerAndReason()
    {
        var cashback = NewCashback(80m, "rejected");
        cashback.FlagForReview();

        await Rejecter().HandleAsync(
            new RejectCashbackCommand(cashback.Id, _reviewerId, "Order was returned"),
            CancellationToken.None);

        var e = Assert.Single(_recorded);
        Assert.Equal(CashbackEventType.Rejected, e.Type);
        Assert.Equal(_reviewerId, e.ActorUserId);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, e.FromStatus);
        Assert.Equal(CashbackStatus.Rejected, e.ToStatus);
        Assert.Equal("rejected", e.NetworkStatus);
        Assert.Equal("Order was returned", e.Reason);
    }

    [Fact]
    public async Task Reverse_RecordsTheReviewerAndReason()
    {
        var cashback = NewCashback(150m, "reversed");
        cashback.Confirm();
        _wallet.ApproveCashback(150m);
        cashback.FlagForReview();

        await Reverser().HandleAsync(
            new ReverseCashbackCommand(cashback.Id, _reviewerId, "Network clawed it back"),
            CancellationToken.None);

        var e = Assert.Single(_recorded);
        Assert.Equal(CashbackEventType.Reversed, e.Type);
        Assert.Equal(_reviewerId, e.ActorUserId);
        Assert.Equal(CashbackStatus.AwaitingAdminReview, e.FromStatus);
        Assert.Equal(CashbackStatus.Reversed, e.ToStatus);
        Assert.Equal("Network clawed it back", e.Reason);
    }

    [Fact]
    public async Task ARefusedDecision_RecordsNothingAndSavesNothing()
    {
        // Reject on a previously confirmed cashback is refused.
        var cashback = NewCashback();
        cashback.Confirm();
        _wallet.ApproveCashback(150m);
        cashback.FlagForReview();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Rejecter().HandleAsync(
                new RejectCashbackCommand(cashback.Id, _reviewerId, "nope"), CancellationToken.None));

        Assert.Empty(_recorded);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ANetworkStatusIsOptionalInTheTrail_WhenTheConversionWasNotLoaded()
    {
        // Reject is not held to the network rule, so it can still be recorded
        // when no network status is known.
        var cashback = NewCashback(networkStatus: null);

        await Rejecter().HandleAsync(
            new RejectCashbackCommand(cashback.Id, _reviewerId, "test reason"), CancellationToken.None);

        Assert.Null(Assert.Single(_recorded).NetworkStatus);
    }

    // ---- the read query

    [Fact]
    public async Task Query_ReturnsTheTrailWithTheAdminsName()
    {
        var cashback = NewCashback();
        var admin = new User("Asha Admin", "asha@example.com", "9876543210", "hash", Guid.NewGuid());
        var created = new CashbackEvent(cashback.Id, CashbackEventType.Created, null, null, CashbackStatus.Pending, 150m, "pending", null);
        var approved = new CashbackEvent(cashback.Id, CashbackEventType.Approved, admin.Id, CashbackStatus.Pending, CashbackStatus.Confirmed, 150m, "validated", "ok");
        typeof(CashbackEvent).GetProperty(nameof(CashbackEvent.Actor))!.SetValue(approved, admin);
        _events.Setup(e => e.ListByCashbackIdAsync(cashback.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { created, approved });

        var result = await new GetCashbackEventsQueryHandler(_cashbacks.Object, _events.Object)
            .HandleAsync(new GetCashbackEventsQuery(cashback.Id), CancellationToken.None);

        Assert.NotNull(result);
        Assert.Equal(2, result!.Count);
        Assert.Equal("Created", result[0].Type);
        Assert.Null(result[0].ActorUserId);
        Assert.Null(result[0].ActorName);
        Assert.Null(result[0].FromStatus);
        Assert.Equal("Approved", result[1].Type);
        Assert.Equal("Asha Admin", result[1].ActorName);
        Assert.Equal("asha@example.com", result[1].ActorEmail);
        Assert.Equal("Pending", result[1].FromStatus);
        Assert.Equal("Confirmed", result[1].ToStatus);
        Assert.Equal("ok", result[1].Reason);
    }

    [Fact]
    public async Task Query_ForAnUnknownCashback_ReturnsNull()
    {
        _cashbacks.Setup(c => c.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((Cashback?)null);

        var result = await new GetCashbackEventsQueryHandler(_cashbacks.Object, _events.Object)
            .HandleAsync(new GetCashbackEventsQuery(Guid.NewGuid()), CancellationToken.None);

        Assert.Null(result);
        _events.Verify(e => e.ListByCashbackIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}
