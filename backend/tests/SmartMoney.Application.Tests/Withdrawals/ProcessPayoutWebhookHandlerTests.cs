using Moq;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Application.Features.Withdrawals.ProcessPayoutWebhook;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class ProcessPayoutWebhookHandlerTests
{
    private readonly Mock<IPayoutProvider> _provider = new();
    private readonly Mock<IWithdrawalRepository> _withdrawals = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _transactions = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Wallet _wallet;
    private readonly Withdrawal _withdrawal;
    private readonly Dictionary<string, string> _headers = new();

    public ProcessPayoutWebhookHandlerTests()
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
        _withdrawals.Setup(w => w.GetByReferenceAsync("WD1", It.IsAny<CancellationToken>()))
            .ReturnsAsync(_withdrawal);
        _wallets.Setup(w => w.GetByIdAsync(_wallet.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_wallet);
    }

    private ProcessPayoutWebhookCommandHandler Handler() => new(
        _provider.Object,
        _withdrawals.Object,
        new WithdrawalSettlement(_wallets.Object, _transactions.Object),
        _unitOfWork.Object);

    private void ProviderSays(PayoutState state, string reference = "WD1") =>
        _provider.Setup(p => p.ParseWebhookAsync(
                It.IsAny<PayoutWebhookRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PayoutWebhookEvent(reference, "P1", state, "msg", 1m));

    private Task<PayoutWebhookResult> Send(string provider = "Test") =>
        Handler().HandleAsync(
            new ProcessPayoutWebhookCommand(provider, _headers, "{}"), default);

    [Fact]
    public async Task Unknown_provider_is_refused_before_anything_is_parsed()
    {
        Assert.Equal(PayoutWebhookResult.UnknownProvider, await Send("Other"));

        _provider.Verify(p => p.ParseWebhookAsync(
            It.IsAny<PayoutWebhookRequest>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task The_provider_receives_the_exact_bytes_not_re_encoded_text()
    {
        // A UTF-8 BOM and a byte sequence that is not valid UTF-8: both are
        // altered by a decode/encode round trip, which would break a signature
        // the vendor computed over the original bytes.
        byte[] raw = { 0xEF, 0xBB, 0xBF, (byte)'{', 0xFF, 0xFE, (byte)'}' };
        ReadOnlyMemory<byte> seen = default;
        _provider.Setup(p => p.ParseWebhookAsync(
                It.IsAny<PayoutWebhookRequest>(), It.IsAny<CancellationToken>()))
            .Callback<PayoutWebhookRequest, CancellationToken>((r, _) => seen = r.RawBody)
            .ReturnsAsync((PayoutWebhookEvent?)null);

        await Handler().HandleAsync(
            new ProcessPayoutWebhookCommand("Test", _headers, raw), default);

        Assert.Equal(raw, seen.ToArray());
    }

    [Fact]
    public async Task Provider_name_match_ignores_case()
    {
        ProviderSays(PayoutState.Succeeded);

        Assert.Equal(PayoutWebhookResult.Applied, await Send("tEsT"));
    }

    [Fact]
    public async Task Failed_signature_is_invalid_and_changes_nothing()
    {
        _provider.Setup(p => p.ParseWebhookAsync(
                It.IsAny<PayoutWebhookRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PayoutWebhookEvent?)null);

        Assert.Equal(PayoutWebhookResult.Invalid, await Send());
        Assert.Equal(WithdrawalStatus.Processing, _withdrawal.Status);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Success_completes_and_saves_once_then_repeat_is_a_duplicate()
    {
        ProviderSays(PayoutState.Succeeded);

        Assert.Equal(PayoutWebhookResult.Applied, await Send());
        Assert.Equal(PayoutWebhookResult.Duplicate, await Send());

        Assert.Equal(WithdrawalStatus.Completed, _withdrawal.Status);
        Assert.Equal(400m, _wallet.TotalWithdrawn);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Failure_refunds_the_user()
    {
        ProviderSays(PayoutState.Failed);

        Assert.Equal(PayoutWebhookResult.Applied, await Send());
        Assert.Equal(1000m, _wallet.AvailableBalance);
    }

    [Fact]
    public async Task Pending_is_ignored()
    {
        ProviderSays(PayoutState.Pending);

        Assert.Equal(PayoutWebhookResult.Ignored, await Send());
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Contradiction_is_flagged_and_saved()
    {
        ProviderSays(PayoutState.Failed);
        await Send();
        ProviderSays(PayoutState.Succeeded);

        Assert.Equal(PayoutWebhookResult.NeedsAttention, await Send());
        Assert.True(_withdrawal.NeedsAttention);
        Assert.Equal(0m, _wallet.TotalWithdrawn);
    }

    [Fact]
    public async Task Unknown_reference_is_acknowledged_without_error()
    {
        ProviderSays(PayoutState.Succeeded, "WD-NOPE");

        Assert.Equal(PayoutWebhookResult.Ignored, await Send());
    }

    [Fact]
    public async Task Falls_back_to_the_provider_reference()
    {
        _provider.Setup(p => p.ParseWebhookAsync(
                It.IsAny<PayoutWebhookRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PayoutWebhookEvent("OTHER", "P1", PayoutState.Succeeded, null, null));
        _withdrawals.Setup(w => w.GetByProviderReferenceAsync(
                "Test", "P1", It.IsAny<CancellationToken>()))
            .ReturnsAsync(_withdrawal);

        Assert.Equal(PayoutWebhookResult.Applied, await Send());
    }
}
