using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks;
using SmartMoney.Application.Features.Cashbacks.ApproveCashback;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Cashbacks;

public sealed class CashbackApprovalGateTests
{
    // ---- the policy on its own

    [Theory]
    [InlineData("validated")]
    [InlineData("Validated")]
    [InlineData("  VALIDATED ")]
    [InlineData("paid")]
    [InlineData("Paid")]
    public void ValidatedAndPaid_AreApprovable(string status)
    {
        Assert.Null(CashbackApprovalPolicy.Refusal(status));
    }

    [Theory]
    [InlineData("pending", "still reports this sale as pending")]
    [InlineData("rejected", "reports this sale as rejected")]
    [InlineData("cancelled", "reports this sale as cancelled")]
    [InlineData("reversed", "reports this sale as reversed")]
    [InlineData("invoice_raised", "'invoice_raised'")]
    [InlineData("", "not known")]
    [InlineData(null, "not known")]
    public void EveryOtherStatus_IsRefusedWithAPlainReason(string? status, string expectedPart)
    {
        string? refusal = CashbackApprovalPolicy.Refusal(status);

        Assert.NotNull(refusal);
        Assert.Contains(expectedPart, refusal);
    }

    // ---- the handler

    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();
    private readonly Mock<ICashbackEventRepository> _events = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly List<CashbackEvent> _recorded = new();
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _reviewerId = Guid.NewGuid();
    private readonly Wallet _wallet;

    public CashbackApprovalGateTests()
    {
        _wallet = new Wallet(_userId);
        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>())).ReturnsAsync(_wallet);
        _events.Setup(e => e.AddAsync(It.IsAny<CashbackEvent>(), It.IsAny<CancellationToken>()))
            .Callback<CashbackEvent, CancellationToken>((e, _) => _recorded.Add(e))
            .Returns(Task.CompletedTask);
    }

    private ApproveCashbackCommandHandler Handler() =>
        new(_cashbacks.Object, _wallets.Object, _walletTransactions.Object, _events.Object, _unitOfWork.Object);

    private Cashback PendingCashback(string? networkStatus, bool flagged = false)
    {
        var cashback = new Cashback(_userId, _wallet.Id, Guid.NewGuid(), 150m, DateTime.UtcNow.AddDays(30));
        _wallet.AddPendingCashback(150m);
        if (networkStatus is not null)
        {
            typeof(Cashback).GetProperty(nameof(Cashback.AffiliateConversion))!
                .SetValue(cashback, new AffiliateConversion { NetworkStatus = networkStatus });
        }
        if (flagged) cashback.FlagForReview();
        _cashbacks.Setup(c => c.GetByIdAsync(cashback.Id, It.IsAny<CancellationToken>())).ReturnsAsync(cashback);
        return cashback;
    }

    private void AssertNothingHappened(Cashback cashback)
    {
        Assert.NotEqual(CashbackStatus.Confirmed, cashback.Status);
        Assert.Equal(0m, _wallet.AvailableBalance);
        Assert.Equal(150m, _wallet.PendingBalance);
        Assert.Empty(_recorded);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Theory]
    [InlineData("pending")]
    [InlineData("rejected")]
    [InlineData("cancelled")]
    [InlineData("reversed")]
    [InlineData("something_new")]
    public async Task Approve_IsRefused_WhileTheNetworkIsNotValidated(string status)
    {
        var cashback = PendingCashback(status);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Handler().HandleAsync(new ApproveCashbackCommand(cashback.Id, _reviewerId, "ok"), CancellationToken.None));

        Assert.Contains("affiliate network", ex.Message);
        AssertNothingHappened(cashback);
    }

    [Fact]
    public async Task Approve_IsRefused_WhenTheNetworkStatusIsUnknown()
    {
        var cashback = PendingCashback(networkStatus: null);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Handler().HandleAsync(new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None));

        AssertNothingHappened(cashback);
    }

    [Fact]
    public async Task Approve_IsRefused_ForAFlaggedCashbackWhoseNetworkSaysRejected()
    {
        // The review queue case: the network rejected it, and Approve must not
        // quietly credit it.
        var cashback = PendingCashback("rejected", flagged: true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Handler().HandleAsync(new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None));

        AssertNothingHappened(cashback);
    }

    [Theory]
    [InlineData("validated")]
    [InlineData("paid")]
    public async Task Approve_Works_OnceTheNetworkValidated_AndIsNotAnOverride(string status)
    {
        var cashback = PendingCashback(status);

        await Handler().HandleAsync(new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None);

        Assert.Equal(CashbackStatus.Confirmed, cashback.Status);
        Assert.Equal(150m, _wallet.AvailableBalance);
        Assert.Equal(CashbackEventType.Approved, Assert.Single(_recorded).Type);
    }

    [Fact]
    public async Task Override_ApprovesAgainstTheNetwork_AndIsRecordedAsSuch()
    {
        var cashback = PendingCashback("pending");

        await Handler().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId, "Merchant emailed confirmation", @override: true),
            CancellationToken.None);

        Assert.Equal(CashbackStatus.Confirmed, cashback.Status);
        Assert.Equal(150m, _wallet.AvailableBalance);
        var e = Assert.Single(_recorded);
        Assert.Equal(CashbackEventType.ApprovedByOverride, e.Type);
        Assert.Equal(_reviewerId, e.ActorUserId);
        Assert.Equal("pending", e.NetworkStatus);
        Assert.Equal("Merchant emailed confirmation", e.Reason);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Override_NeedsAReason(string? reason)
    {
        var cashback = PendingCashback("pending");

        await Assert.ThrowsAsync<ArgumentException>(() =>
            Handler().HandleAsync(new ApproveCashbackCommand(cashback.Id, _reviewerId, reason, @override: true), CancellationToken.None));

        AssertNothingHappened(cashback);
    }

    [Fact]
    public async Task Override_OnAnAlreadyValidatedSale_IsJustAnApproval()
    {
        var cashback = PendingCashback("validated");

        await Handler().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId, @override: true), CancellationToken.None);

        Assert.Equal(CashbackEventType.Approved, Assert.Single(_recorded).Type);
    }

    [Fact]
    public async Task ReApprovingAReversedReport_NeedsAnOverrideToo_AndStillCreditsNothingTwice()
    {
        // Confirmed earlier, then the network reversed it: keeping it is an
        // override, and it must not credit the wallet a second time.
        var cashback = PendingCashback("reversed");
        cashback.Confirm();
        _wallet.ApproveCashback(150m);
        cashback.FlagForReview();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Handler().HandleAsync(new ApproveCashbackCommand(cashback.Id, _reviewerId), CancellationToken.None));

        await Handler().HandleAsync(
            new ApproveCashbackCommand(cashback.Id, _reviewerId, "Network error, order is fine", @override: true),
            CancellationToken.None);

        Assert.Equal(150m, _wallet.AvailableBalance);
        Assert.Equal(CashbackEventType.ApprovedByOverride, Assert.Single(_recorded).Type);
    }
}
