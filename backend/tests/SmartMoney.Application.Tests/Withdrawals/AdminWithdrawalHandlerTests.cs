using Moq;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Application.Features.Withdrawals.AcknowledgeWithdrawal;
using SmartMoney.Application.Features.Withdrawals.ApproveWithdrawal;
using SmartMoney.Application.Features.Withdrawals.CancelWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawal;
using SmartMoney.Application.Features.Withdrawals.MarkWithdrawalFailed;
using SmartMoney.Application.Features.Withdrawals.MarkWithdrawalPaid;
using SmartMoney.Application.Features.Withdrawals.RejectWithdrawal;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class AdminWithdrawalHandlerTests
{
    private static readonly PayoutDestination Upi = new(
        PayoutMethod.Upi, "Asha Rao", "asha@okhdfc", null, null);

    private readonly Mock<IWithdrawalRepository> _withdrawals = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _transactions = new();
    private readonly Mock<IPayoutProvider> _provider = new();
    private readonly Mock<IPayoutDestinationProtector> _protector = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly List<WalletTransaction> _entries = new();
    private readonly Guid _admin = Guid.NewGuid();

    private readonly Wallet _wallet;
    private readonly Withdrawal _withdrawal;
    private readonly PayoutPolicy _policy = new(new PayoutOptions { MaxSubmissionAttempts = 3 });

    public AdminWithdrawalHandlerTests()
    {
        Guid userId = Guid.NewGuid();

        _wallet = new Wallet(userId);
        _wallet.AddPendingCashback(1000m);
        _wallet.ApproveCashback(1000m);
        _wallet.HoldForWithdrawal(400m);

        _withdrawal = new Withdrawal(
            userId, _wallet.Id, "WD1", 400m, 4m, 2m,
            PayoutMethod.Upi, "as****@okhdfc", "protected");

        _withdrawals.Setup(w => w.GetByIdAsync(_withdrawal.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_withdrawal);
        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
        _transactions.Setup(t => t.AddAsync(
                It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()))
            .Callback<WalletTransaction, CancellationToken>((tx, _) => _entries.Add(tx));
        _protector.Setup(p => p.Unprotect("protected")).Returns(Upi);
        _provider.SetupGet(p => p.Name).Returns("Test");
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(false);
    }

    private WithdrawalSettlement Settlement() => new(_wallets.Object, _transactions.Object);

    private WithdrawalProcessor Processor() => new(
        _withdrawals.Object, _provider.Object, _protector.Object,
        Settlement(), _policy, _unitOfWork.Object);

    // ---- approve -------------------------------------------------------

    private ApproveWithdrawalCommandHandler ApproveHandler() => new(
        _withdrawals.Object, _wallets.Object, Processor(), _unitOfWork.Object);

    [Fact]
    public async Task Approve_with_manual_provider_only_approves()
    {
        var result = await ApproveHandler().HandleAsync(
            new ApproveWithdrawalCommand(_withdrawal.Id, _admin), default);

        Assert.Equal("Approved", result!.Status);
        Assert.Equal(_admin, _withdrawal.ReviewedByUserId);
        _provider.Verify(p => p.SubmitAsync(
            It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Approve_of_unknown_withdrawal_returns_null()
    {
        Assert.Null(await ApproveHandler().HandleAsync(
            new ApproveWithdrawalCommand(Guid.NewGuid(), _admin), default));
    }

    [Fact]
    public async Task Approve_with_automatic_provider_submits_and_goes_to_processing()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(PayoutSubmissionResult.Accepted("PROV-1"));

        var result = await ApproveHandler().HandleAsync(
            new ApproveWithdrawalCommand(_withdrawal.Id, _admin), default);

        Assert.Equal("Processing", result!.Status);
        Assert.Equal("PROV-1", _withdrawal.ProviderReference);
        Assert.Equal(400m, _wallet.HeldBalance);
        _provider.Verify(p => p.SubmitAsync(
            It.Is<PayoutInstruction>(i =>
                i.Reference == "WD1" && i.Amount == 398m && i.Destination == Upi),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    // Saves, in order: 1 the approval, 2 the "about to send" marker, 3 the result.

    [Fact]
    public async Task Approve_survives_a_race_after_the_provider_answered()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(PayoutSubmissionResult.Accepted("PROV-1"));
        int saves = 0;
        _unitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(() => ++saves == 3
                ? throw new ConcurrencyConflictException(new Exception("race"))
                : 1);

        var result = await ApproveHandler().HandleAsync(
            new ApproveWithdrawalCommand(_withdrawal.Id, _admin), default);

        Assert.NotNull(result);
        _provider.Verify(p => p.SubmitAsync(
            It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Losing_the_race_before_sending_means_nothing_is_sent()
    {
        // E.g. an admin rejected it between our load and our "about to send" save.
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        int saves = 0;
        _unitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(() => ++saves == 2
                ? throw new ConcurrencyConflictException(new Exception("race"))
                : 1);

        await ApproveHandler().HandleAsync(
            new ApproveWithdrawalCommand(_withdrawal.Id, _admin), default);

        _provider.Verify(p => p.SubmitAsync(
            It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task The_attempt_is_saved_before_the_provider_is_called()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        var order = new List<string>();
        bool markerSavedBeforeCall = false;
        _unitOfWork.Setup(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .Callback(() =>
            {
                order.Add("save");
                markerSavedBeforeCall |= _withdrawal.SubmissionStarted && !order.Contains("send");
            })
            .ReturnsAsync(1);
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .Callback(() => order.Add("send"))
            .ReturnsAsync(PayoutSubmissionResult.Accepted("P"));
        _withdrawal.Approve(_admin);

        await Processor().SubmitAsync(_withdrawal.Id, default);

        Assert.True(markerSavedBeforeCall);
        Assert.Equal(new[] { "save", "send", "save" }, order);
    }

    // ---- processor outcomes -------------------------------------------

    [Fact]
    public async Task Processor_completes_when_provider_finishes_instantly()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(PayoutSubmissionResult.Completed("UTR9", 1.5m));
        _withdrawal.Approve(_admin);

        await Processor().SubmitAsync(_withdrawal.Id, default);

        Assert.Equal(WithdrawalStatus.Completed, _withdrawal.Status);
        Assert.Equal(400m, _wallet.TotalWithdrawn);
        Assert.Equal(1.5m, _withdrawal.ActualProviderFee);
        Assert.Single(_entries);
    }

    [Fact]
    public async Task Processor_fails_and_refunds_on_permanent_rejection_hiding_the_raw_message()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(PayoutSubmissionResult.Rejected("INVALID_VPA_9923"));
        _withdrawal.Approve(_admin);

        await Processor().SubmitAsync(_withdrawal.Id, default);

        Assert.Equal(WithdrawalStatus.Failed, _withdrawal.Status);
        Assert.Equal(1000m, _wallet.AvailableBalance);
        Assert.DoesNotContain("INVALID_VPA", _withdrawal.FailureReason);
        Assert.Equal("INVALID_VPA_9923", _withdrawal.LastError);
    }

    [Fact]
    public async Task Processor_keeps_retrying_then_flags_after_the_limit()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("timeout"));
        _withdrawal.Approve(_admin);

        for (int i = 0; i < 5; i++)
        {
            await Processor().SubmitAsync(_withdrawal.Id, default);
        }

        Assert.Equal(WithdrawalStatus.Approved, _withdrawal.Status);
        Assert.Equal(3, _withdrawal.SubmissionAttempts);
        Assert.True(_withdrawal.NeedsAttention);
        Assert.Contains("timeout", _withdrawal.LastError);
        _provider.Verify(p => p.SubmitAsync(
            It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()), Times.Exactly(3));
    }

    [Fact]
    public async Task Processor_flags_an_unreadable_destination_without_calling_the_provider()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _protector.Setup(p => p.Unprotect("protected"))
            .Throws(new System.Security.Cryptography.CryptographicException("key lost"));
        _withdrawal.Approve(_admin);

        await Processor().SubmitAsync(_withdrawal.Id, default);

        Assert.True(_withdrawal.NeedsAttention);
        _provider.Verify(p => p.SubmitAsync(
            It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task An_unreadable_destination_is_flagged_once_and_not_retried()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _protector.Setup(p => p.Unprotect("protected"))
            .Throws(new System.Security.Cryptography.CryptographicException("key lost"));
        _withdrawal.Approve(_admin);

        for (int i = 0; i < 5; i++)
        {
            await Processor().SubmitAsync(_withdrawal.Id, default);
        }

        _protector.Verify(p => p.Unprotect(It.IsAny<string>()), Times.Once);
        Assert.Equal(1, _withdrawal.SubmissionAttempts);
        Assert.Equal(
            "Stored destination is unreadable; pay manually or reject.",
            _withdrawal.ReviewNote);
    }

    [Fact]
    public async Task Acknowledging_an_unreadable_destination_makes_it_retryable_again()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _protector.SetupSequence(p => p.Unprotect("protected"))
            .Throws(new System.Security.Cryptography.CryptographicException("key lost"))
            .Returns(Upi);
        _provider.Setup(p => p.SubmitAsync(
                It.IsAny<PayoutInstruction>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(PayoutSubmissionResult.Accepted("P1"));
        _withdrawal.Approve(_admin);
        await Processor().SubmitAsync(_withdrawal.Id, default);

        await new AcknowledgeWithdrawalCommandHandler(
                _withdrawals.Object, _wallets.Object, _unitOfWork.Object)
            .HandleAsync(new AcknowledgeWithdrawalCommand(_withdrawal.Id), default);
        await Processor().SubmitAsync(_withdrawal.Id, default);

        Assert.Equal(WithdrawalStatus.Processing, _withdrawal.Status);
    }

    // ---- decision responses -------------------------------------------

    [Fact]
    public async Task User_cancel_and_admin_actions_report_the_same_shape()
    {
        var cancelled = await new CancelWithdrawalCommandHandler(
                _withdrawals.Object, _wallets.Object, Settlement(), _unitOfWork.Object)
            .HandleAsync(new CancelWithdrawalCommand(_withdrawal.UserId, _withdrawal.Id), default);

        Assert.Equal("Cancelled", cancelled.Status);
        Assert.Equal(_withdrawal.Reference, cancelled.Reference);
        Assert.Equal(_wallet.AvailableBalance, cancelled.AvailableBalance);
        Assert.Equal(_wallet.HeldBalance, cancelled.HeldBalance);
    }

    // ---- reject --------------------------------------------------------

    private RejectWithdrawalCommandHandler RejectHandler() => new(
        _withdrawals.Object, _wallets.Object, _provider.Object, _policy,
        Settlement(), _unitOfWork.Object);

    private Task<WithdrawalDecisionResponse?> Reject() => RejectHandler().HandleAsync(
        new RejectWithdrawalCommand(_withdrawal.Id, _admin, "Declined"), default);

    [Fact]
    public async Task Reject_is_refused_once_an_automatic_payout_has_been_attempted()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawal.Approve(_admin);
        _withdrawal.BeginSubmission("Test");

        await Assert.ThrowsAsync<InvalidOperationException>(Reject);

        Assert.Equal(WithdrawalStatus.Approved, _withdrawal.Status);
        Assert.Equal(400m, _wallet.HeldBalance);
        Assert.Empty(_entries);
    }

    [Fact]
    public async Task Reject_is_refused_after_a_timed_out_attempt_that_may_have_reached_the_provider()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawal.Approve(_admin);
        _withdrawal.RecordSubmissionFailure("Test", "timeout");

        await Assert.ThrowsAsync<InvalidOperationException>(Reject);
    }

    [Fact]
    public async Task Reject_is_allowed_before_any_attempt_even_with_an_automatic_provider()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawal.Approve(_admin);

        var result = await Reject();

        Assert.Equal("Rejected", result!.Status);
        Assert.Equal(1000m, result.AvailableBalance);
    }

    [Fact]
    public async Task Reject_is_allowed_after_an_attempt_once_it_needs_attention()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawal.Approve(_admin);
        _withdrawal.BeginSubmission("Test");
        _withdrawal.FlagNeedsAttention("admin checked the provider");

        var result = await Reject();

        Assert.Equal("Rejected", result!.Status);
        Assert.False(_withdrawal.NeedsAttention);
    }

    [Fact]
    public async Task Reject_is_allowed_after_an_attempt_once_retries_are_used_up()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawal.Approve(_admin);
        for (int i = 0; i < 3; i++)
        {
            _withdrawal.RecordSubmissionFailure("Test", "down");
        }

        Assert.Equal("Rejected", (await Reject())!.Status);
    }

    [Fact]
    public async Task Reject_is_always_allowed_with_the_manual_provider()
    {
        _withdrawal.Approve(_admin);
        _withdrawal.BeginSubmission("Manual");

        Assert.Equal("Rejected", (await Reject())!.Status);
    }

    [Fact]
    public async Task Reject_returns_money_and_requires_a_reason()
    {
        var handler = RejectHandler();

        await Assert.ThrowsAsync<ArgumentException>(() => handler.HandleAsync(
            new RejectWithdrawalCommand(_withdrawal.Id, _admin, " "), default));

        var result = await handler.HandleAsync(
            new RejectWithdrawalCommand(_withdrawal.Id, _admin, "Name does not match"), default);

        Assert.Equal("Rejected", result!.Status);
        Assert.Equal(1000m, result.AvailableBalance);
        Assert.Equal(0m, result.HeldBalance);
    }

    // ---- mark paid / failed -------------------------------------------

    private MarkWithdrawalPaidCommandHandler PaidHandler() => new(
        _withdrawals.Object, _wallets.Object, _provider.Object, _policy,
        Settlement(), _unitOfWork.Object);

    private MarkWithdrawalFailedCommandHandler FailedHandler() => new(
        _withdrawals.Object, _wallets.Object, _provider.Object, _policy,
        Settlement(), _unitOfWork.Object);

    [Fact]
    public async Task Mark_paid_on_a_requested_withdrawal_approves_and_completes()
    {
        var result = await PaidHandler().HandleAsync(
            new MarkWithdrawalPaidCommand(_withdrawal.Id, _admin, "  UTR123456  "), default);

        Assert.Equal("Completed", result!.Status);
        Assert.Equal("UTR123456", _withdrawal.ProviderReference);
        Assert.Equal(_admin, _withdrawal.ReviewedByUserId);
        Assert.Equal(400m, _wallet.TotalWithdrawn);
        Assert.Equal(0m, result.HeldBalance);
    }

    [Fact]
    public async Task Mark_paid_needs_a_reference()
    {
        await Assert.ThrowsAsync<ArgumentException>(() => PaidHandler().HandleAsync(
            new MarkWithdrawalPaidCommand(_withdrawal.Id, _admin, ""), default));
    }

    [Fact]
    public async Task Mark_paid_twice_is_refused_and_pays_once()
    {
        await PaidHandler().HandleAsync(
            new MarkWithdrawalPaidCommand(_withdrawal.Id, _admin, "UTR1"), default);

        await Assert.ThrowsAsync<InvalidOperationException>(() => PaidHandler().HandleAsync(
            new MarkWithdrawalPaidCommand(_withdrawal.Id, _admin, "UTR2"), default));

        Assert.Equal(400m, _wallet.TotalWithdrawn);
        Assert.Single(_entries);
    }

    [Fact]
    public async Task Automatic_provider_blocks_manual_settlement_until_it_needs_attention()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawal.Approve(_admin);
        _withdrawal.MarkSubmitted("Test", "P1");

        await Assert.ThrowsAsync<InvalidOperationException>(() => PaidHandler().HandleAsync(
            new MarkWithdrawalPaidCommand(_withdrawal.Id, _admin, "UTR1"), default));
        await Assert.ThrowsAsync<InvalidOperationException>(() => FailedHandler().HandleAsync(
            new MarkWithdrawalFailedCommand(_withdrawal.Id, "Bank returned it"), default));

        _withdrawal.FlagNeedsAttention("check");

        var result = await PaidHandler().HandleAsync(
            new MarkWithdrawalPaidCommand(_withdrawal.Id, _admin, "UTR1"), default);

        Assert.Equal("Completed", result!.Status);
        Assert.False(_withdrawal.NeedsAttention);
    }

    [Fact]
    public async Task Automatic_provider_allows_manual_settlement_when_retries_are_used_up()
    {
        _provider.SetupGet(p => p.SupportsAutomaticPayout).Returns(true);
        _withdrawal.Approve(_admin);
        for (int i = 0; i < 3; i++)
        {
            _withdrawal.RecordSubmissionFailure("Test", "down");
        }

        var result = await FailedHandler().HandleAsync(
            new MarkWithdrawalFailedCommand(_withdrawal.Id, "Could not be sent"), default);

        Assert.Equal("Failed", result!.Status);
        Assert.Equal(1000m, result.AvailableBalance);
    }

    [Fact]
    public async Task Mark_failed_refunds_and_shows_the_admin_reason()
    {
        _withdrawal.Approve(_admin);

        var result = await FailedHandler().HandleAsync(
            new MarkWithdrawalFailedCommand(_withdrawal.Id, "Account closed"), default);

        Assert.Equal("Failed", result!.Status);
        Assert.Equal("Account closed", _withdrawal.FailureReason);
        Assert.Equal(1000m, _wallet.AvailableBalance);
    }

    [Fact]
    public async Task Mark_failed_on_a_requested_withdrawal_is_refused()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => FailedHandler().HandleAsync(
            new MarkWithdrawalFailedCommand(_withdrawal.Id, "No"), default));

        Assert.Equal(400m, _wallet.HeldBalance);
    }

    // ---- acknowledge ---------------------------------------------------

    [Fact]
    public async Task Acknowledge_clears_the_flag_and_changes_no_money()
    {
        _withdrawal.FlagNeedsAttention("look");

        var handler = new AcknowledgeWithdrawalCommandHandler(
            _withdrawals.Object, _wallets.Object, _unitOfWork.Object);
        var result = await handler.HandleAsync(
            new AcknowledgeWithdrawalCommand(_withdrawal.Id), default);

        Assert.False(_withdrawal.NeedsAttention);
        Assert.Equal(400m, result!.HeldBalance);
        Assert.Empty(_entries);
    }

    // ---- admin detail --------------------------------------------------

    [Fact]
    public async Task Detail_shows_the_destination_only_while_open()
    {
        _withdrawals.Setup(w => w.GetWithUserByIdAsync(_withdrawal.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_withdrawal);
        var handler = new GetAdminWithdrawalQueryHandler(_withdrawals.Object, _protector.Object);

        var open = await handler.HandleAsync(new GetAdminWithdrawalQuery(_withdrawal.Id), default);
        Assert.Equal("asha@okhdfc", open!.Destination!.UpiId);

        _withdrawal.Approve(_admin);
        await Settlement().CompleteAsync(_withdrawal, "UTR1", null, default);

        var settled = await handler.HandleAsync(new GetAdminWithdrawalQuery(_withdrawal.Id), default);
        Assert.Null(settled!.Destination);
        Assert.False(settled.DestinationUnreadable);
    }

    [Fact]
    public async Task Detail_reports_an_unreadable_destination_instead_of_failing()
    {
        _withdrawals.Setup(w => w.GetWithUserByIdAsync(_withdrawal.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_withdrawal);
        _protector.Setup(p => p.Unprotect("protected")).Throws(new InvalidOperationException());
        var handler = new GetAdminWithdrawalQueryHandler(_withdrawals.Object, _protector.Object);

        var result = await handler.HandleAsync(new GetAdminWithdrawalQuery(_withdrawal.Id), default);

        Assert.Null(result!.Destination);
        Assert.True(result.DestinationUnreadable);
    }
}
