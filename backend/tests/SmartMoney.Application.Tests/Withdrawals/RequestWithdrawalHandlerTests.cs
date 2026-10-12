using Moq;
using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Application.Features.Withdrawals.CancelWithdrawal;
using SmartMoney.Application.Features.Withdrawals.PreviewWithdrawal;
using SmartMoney.Application.Features.Withdrawals.RequestWithdrawal;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class RequestWithdrawalHandlerTests
{
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWithdrawalRepository> _withdrawals = new();
    private readonly Mock<IWalletTransactionRepository> _transactions = new();
    private readonly Mock<IPasswordHasher> _hasher = new();
    private readonly Mock<IPayoutDestinationProtector> _protector = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IWithdrawalProcessor> _processor = new();
    private readonly List<WalletTransaction> _entries = new();
    private readonly List<Withdrawal> _added = new();

    private readonly User _user;
    private readonly Wallet _wallet;
    private PayoutOptions _options = new() { FlatFee = 4m, PercentFee = 0m };

    public RequestWithdrawalHandlerTests()
    {
        _user = new User("Asha Rao", "asha@example.com", "9876543210", "hash", Guid.NewGuid());
        _user.ActivateAccount();
        _user.VerifyEmail();

        _wallet = new Wallet(_user.Id);
        _wallet.AddPendingCashback(1000m);
        _wallet.ApproveCashback(1000m);

        _users.Setup(u => u.GetByIdAsync(_user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_user);
        _wallets.Setup(w => w.GetByUserIdAsync(_user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
        _hasher.Setup(h => h.Verify("right", "hash")).Returns(true);
        _protector.Setup(p => p.Protect(It.IsAny<PayoutDestination>())).Returns("protected");
        _transactions.Setup(t => t.AddAsync(
                It.IsAny<WalletTransaction>(), It.IsAny<CancellationToken>()))
            .Callback<WalletTransaction, CancellationToken>((tx, _) => _entries.Add(tx));
        _withdrawals.Setup(w => w.AddAsync(
                It.IsAny<Withdrawal>(), It.IsAny<CancellationToken>()))
            .Callback<Withdrawal, CancellationToken>((w, _) => _added.Add(w));
    }

    private RequestWithdrawalCommandHandler Handler() => new(
        _users.Object, _wallets.Object, _withdrawals.Object, _transactions.Object,
        _hasher.Object, _protector.Object, new PayoutPolicy(_options),
        _processor.Object, _unitOfWork.Object);

    private static RequestWithdrawalRequest UpiRequest(
        decimal amount = 400m, string password = "right") => new()
    {
        Amount = amount,
        Method = "Upi",
        BeneficiaryName = "Asha Rao",
        UpiId = "Asha@okhdfc",
        Password = password
    };

    [Fact]
    public async Task Valid_request_holds_money_and_writes_the_ledger()
    {
        var response = await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default);

        Assert.Equal("Requested", response.Status);
        Assert.Equal(600m, _wallet.AvailableBalance);
        Assert.Equal(400m, _wallet.HeldBalance);

        Withdrawal saved = Assert.Single(_added);
        Assert.Equal("protected", saved.DestinationProtected);
        Assert.StartsWith("WD", saved.Reference);
        Assert.DoesNotContain("asha@okhdfc", saved.DestinationMasked);

        WalletTransaction entry = Assert.Single(_entries);
        Assert.Equal(WalletTransactionType.WithdrawalRequested, entry.Type);
        Assert.Equal(600m, entry.AvailableBalanceAfter);
        Assert.Equal(400m, entry.HeldBalanceAfter);
        Assert.Equal(saved.Id, entry.WithdrawalId);

        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Fee_is_split_and_deducted_from_the_payout()
    {
        // 4 + 18% tax = 4.72 total, user pays half = 2.36.
        var response = await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default);

        Assert.Equal(4.72m, response.FeeTotal);
        Assert.Equal(2.36m, response.UserFee);
        Assert.Equal(397.64m, response.NetAmount);
    }

    [Fact]
    public async Task Upi_id_is_stored_lower_case_in_the_encrypted_destination()
    {
        PayoutDestination? seen = null;
        _protector.Setup(p => p.Protect(It.IsAny<PayoutDestination>()))
            .Callback<PayoutDestination>(d => seen = d)
            .Returns("protected");

        await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default);

        Assert.Equal("asha@okhdfc", seen!.UpiId);
    }

    [Fact]
    public async Task Approval_off_approves_immediately()
    {
        _options = new PayoutOptions { RequireAdminApproval = false };

        var response = await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default);

        Assert.Equal("Approved", response.Status);
        _processor.Verify(p => p.SubmitAsync(
            _added[0].Id, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Approval_required_does_not_submit()
    {
        await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default);

        _processor.Verify(p => p.SubmitAsync(
            It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Request_still_succeeds_when_submission_loses_a_race()
    {
        _options = new PayoutOptions { RequireAdminApproval = false };
        _processor.Setup(p => p.SubmitAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ConcurrencyConflictException(new Exception("race")));

        var response = await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default);

        Assert.Equal("Approved", response.Status);
    }

    [Fact]
    public async Task Wrong_password_changes_nothing()
    {
        await Assert.ThrowsAsync<ArgumentException>(() => Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest(password: "wrong")), default));

        Assert.Equal(1000m, _wallet.AvailableBalance);
        Assert.Empty(_added);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Theory]
    [InlineData(100)]
    [InlineData(60000)]
    [InlineData(300.555)]
    public async Task Amount_outside_limits_is_a_bad_request(double amount)
    {
        await Assert.ThrowsAsync<ArgumentException>(() => Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest((decimal)amount)), default));
    }

    [Fact]
    public async Task More_than_available_is_a_conflict()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest(1200m)), default));

        Assert.Empty(_added);
    }

    [Fact]
    public async Task Second_open_withdrawal_is_refused()
    {
        _withdrawals.Setup(w => w.CountOpenByUserIdAsync(_user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        await Assert.ThrowsAsync<InvalidOperationException>(() => Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default));
    }

    [Fact]
    public async Task Unverified_email_is_refused()
    {
        var unverified = new User("B C", "b@example.com", "9876543211", "hash", Guid.NewGuid());
        unverified.ActivateAccount();
        _users.Setup(u => u.GetByIdAsync(unverified.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(unverified);
        _wallets.Setup(w => w.GetByUserIdAsync(unverified.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);

        await Assert.ThrowsAsync<InvalidOperationException>(() => Handler().HandleAsync(
            new RequestWithdrawalCommand(unverified.Id, UpiRequest()), default));
    }

    [Theory]
    [InlineData("Cash", "x@upi", null, null)]
    [InlineData("Upi", "not-a-upi", null, null)]
    [InlineData("BankTransfer", null, "12345", "HDFC0001234")]
    [InlineData("BankTransfer", null, "123456789012", "HDFC1001234")]
    public async Task Bad_destination_fields_are_a_bad_request(
        string method, string? upi, string? account, string? ifsc)
    {
        var request = new RequestWithdrawalRequest
        {
            Amount = 400m,
            Method = method,
            BeneficiaryName = "Asha Rao",
            UpiId = upi,
            BankAccountNumber = account,
            IfscCode = ifsc,
            Password = "right"
        };

        await Assert.ThrowsAsync<ArgumentException>(() => Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, request), default));
    }

    [Fact]
    public async Task Bank_transfer_normalises_ifsc_and_masks_the_account()
    {
        var request = new RequestWithdrawalRequest
        {
            Amount = 400m,
            Method = "banktransfer",
            BeneficiaryName = "Asha Rao",
            BankAccountNumber = "123456789012",
            IfscCode = "hdfc0001234",
            Password = "right"
        };

        var response = await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, request), default);

        Assert.Equal("HDFC0001234 ****9012", response.Destination);
    }

    [Fact]
    public async Task Cancel_returns_money_for_the_owner_only()
    {
        await Handler().HandleAsync(
            new RequestWithdrawalCommand(_user.Id, UpiRequest()), default);
        Withdrawal saved = _added[0];
        _withdrawals.Setup(w => w.GetByIdAsync(saved.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(saved);

        var cancel = new CancelWithdrawalCommandHandler(
            _withdrawals.Object,
            _wallets.Object,
            new WithdrawalSettlement(_wallets.Object, _transactions.Object),
            _unitOfWork.Object);

        await Assert.ThrowsAsync<KeyNotFoundException>(() => cancel.HandleAsync(
            new CancelWithdrawalCommand(Guid.NewGuid(), saved.Id), default));

        var result = await cancel.HandleAsync(
            new CancelWithdrawalCommand(_user.Id, saved.Id), default);

        Assert.Equal("Cancelled", result.Status);
        Assert.Equal(1000m, result.AvailableBalance);
        Assert.Equal(0m, result.HeldBalance);
    }

    [Fact]
    public async Task Preview_reports_problems_instead_of_throwing()
    {
        var preview = new PreviewWithdrawalQueryHandler(
            _users.Object, _wallets.Object, _withdrawals.Object, new PayoutPolicy(_options));

        var ok = await preview.HandleAsync(new PreviewWithdrawalQuery(_user.Id, 400m), default);
        var tooMuch = await preview.HandleAsync(new PreviewWithdrawalQuery(_user.Id, 5000m), default);
        var tooLittle = await preview.HandleAsync(new PreviewWithdrawalQuery(_user.Id, 10m), default);

        Assert.True(ok.CanWithdraw);
        Assert.Equal(397.64m, ok.NetAmount);
        Assert.False(tooMuch.CanWithdraw);
        Assert.NotNull(tooMuch.Message);
        Assert.False(tooLittle.CanWithdraw);
        Assert.Equal(0m, tooLittle.NetAmount);
    }
}
