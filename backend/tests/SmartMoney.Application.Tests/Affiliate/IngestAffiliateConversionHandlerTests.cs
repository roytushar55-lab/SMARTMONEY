using Moq;
using SmartMoney.Application.Abstractions.CashbackRates;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Affiliate;

public sealed class IngestAffiliateConversionHandlerTests
{
    private readonly Mock<IAffiliateNetworkRepository> _networks = new();
    private readonly Mock<IAffiliateConversionRepository> _conversions = new();
    private readonly Mock<IAffiliateClickRepository> _clicks = new();
    private readonly Mock<ICashbackRepository> _cashbacks = new();
    private readonly Mock<ICashbackRateResolver> _rateResolver = new();
    private readonly Mock<IStoreRepository> _stores = new();
    private readonly Mock<IWalletRepository> _wallets = new();
    private readonly Mock<IWalletTransactionRepository> _walletTransactions = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private readonly AffiliateNetwork _network = new()
    {
        Id = Guid.NewGuid(),
        Name = "Cuelinks",
        Code = "CUELINKS",
    };

    public IngestAffiliateConversionHandlerTests()
    {
        _networks.Setup(n => n.GetByCodeAsync("CUELINKS", It.IsAny<CancellationToken>()))
            .ReturnsAsync(_network);
    }

    private IngestAffiliateConversionCommandHandler CreateHandler()
    {
        var processor = new ConversionCashbackProcessor(
            _cashbacks.Object, _rateResolver.Object, _stores.Object, _wallets.Object,
            _clicks.Object, _walletTransactions.Object);

        return new IngestAffiliateConversionCommandHandler(
            new IngestAffiliateConversionValidator(),
            _networks.Object,
            _conversions.Object,
            _clicks.Object,
            processor,
            _unitOfWork.Object);
    }

    private static IngestAffiliateConversionCommand Command(
        string status = "pending",
        string? trackingReference = "ref-1",
        string? rawPayload = "{\"a\":1}")
    {
        return new IngestAffiliateConversionCommand(
            "cuelinks",
            "TXN-42",
            trackingReference,
            status,
            2499.00m,
            250.00m,
            "INR",
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow,
            rawPayload);
    }

    [Fact]
    public async Task FirstIngestion_CreatesConversion()
    {
        var response = await CreateHandler().HandleAsync(Command(), CancellationToken.None);

        Assert.Equal("Created", response.Outcome);
        _conversions.Verify(
            c => c.AddAsync(
                It.Is<AffiliateConversion>(x =>
                    x.NetworkTransactionId == "TXN-42"
                    && x.AffiliateNetworkId == _network.Id),
                It.IsAny<CancellationToken>()),
            Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Replay_UpdatesExistingConversion_InsteadOfInserting()
    {
        var existing = new AffiliateConversion
        {
            AffiliateNetworkId = _network.Id,
            NetworkTransactionId = "TXN-42",
            NetworkStatus = "pending",
        };
        _conversions.Setup(c => c.GetByNetworkAndTransactionIdAsync(
                _network.Id, "TXN-42", It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        var response = await CreateHandler().HandleAsync(
            Command(status: "validated"), CancellationToken.None);

        Assert.Equal("Updated", response.Outcome);
        Assert.Equal("validated", existing.NetworkStatus);
        _conversions.Verify(
            c => c.AddAsync(It.IsAny<AffiliateConversion>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task Attribution_IsFrozenOnceSet()
    {
        var originalClickId = Guid.NewGuid();
        var existing = new AffiliateConversion
        {
            AffiliateNetworkId = _network.Id,
            NetworkTransactionId = "TXN-42",
            AffiliateClickId = originalClickId,
            TrackingReference = "ref-original",
        };
        _conversions.Setup(c => c.GetByNetworkAndTransactionIdAsync(
                _network.Id, "TXN-42", It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateHandler().HandleAsync(
            Command(trackingReference: "ref-DIFFERENT"), CancellationToken.None);

        Assert.Equal(originalClickId, existing.AffiliateClickId);
        Assert.Equal("ref-original", existing.TrackingReference);
    }

    [Fact]
    public async Task NullRawPayload_DoesNotEraseStoredPayload()
    {
        var existing = new AffiliateConversion
        {
            AffiliateNetworkId = _network.Id,
            NetworkTransactionId = "TXN-42",
            RawPayload = "{\"original\":true}",
        };
        _conversions.Setup(c => c.GetByNetworkAndTransactionIdAsync(
                _network.Id, "TXN-42", It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        await CreateHandler().HandleAsync(
            Command(rawPayload: null), CancellationToken.None);

        Assert.Equal("{\"original\":true}", existing.RawPayload);
    }

    [Fact]
    public async Task UnknownNetworkCode_Throws()
    {
        _networks.Setup(n => n.GetByCodeAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((AffiliateNetwork?)null);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => CreateHandler().HandleAsync(Command(), CancellationToken.None));
    }

    [Fact]
    public async Task UnresolvableTrackingReference_StoresConversionUnattributed()
    {
        _clicks.Setup(c => c.GetByTrackingReferenceAsync("ref-1", It.IsAny<CancellationToken>()))
            .ReturnsAsync((AffiliateClick?)null);

        var response = await CreateHandler().HandleAsync(Command(), CancellationToken.None);

        Assert.Equal("Created", response.Outcome);
        Assert.False(response.Attributed);
        _cashbacks.Verify(
            c => c.AddAsync(It.IsAny<Cashback>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
