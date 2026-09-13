using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.StoreAffiliateMappings;

public sealed class CreateStoreAffiliateMappingHandlerTests
{
    private readonly Mock<IStoreAffiliateMappingRepository> _mappings = new();
    private readonly Mock<IStoreRepository> _stores = new();
    private readonly Mock<IAffiliateNetworkRepository> _networks = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private readonly Store _store = new() { Name = "Myntra", Slug = "myntra" };
    private readonly AffiliateNetwork _network = new() { Name = "Cuelinks", Code = "CUELINKS" };

    public CreateStoreAffiliateMappingHandlerTests()
    {
        _stores.Setup(s => s.GetByIdAsync(_store.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_store);
        _networks.Setup(n => n.GetByIdAsync(_network.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_network);
    }

    private CreateStoreAffiliateMappingCommandHandler CreateHandler()
    {
        return new CreateStoreAffiliateMappingCommandHandler(
            _mappings.Object, _stores.Object, _networks.Object,
            new CreateStoreAffiliateMappingValidator(), _unitOfWork.Object);
    }

    private CreateStoreAffiliateMappingCommand ValidCommand()
    {
        return new CreateStoreAffiliateMappingCommand(
            _store.Id, _network.Id, "CL-MYNTRA", "Myntra", "https://www.myntra.com");
    }

    [Fact]
    public async Task ValidRequest_CreatesMapping()
    {
        var response = await CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("Myntra", response!.StoreName);
        Assert.Equal("Cuelinks", response.AffiliateNetworkName);
        Assert.Equal("CL-MYNTRA", response.ExternalMerchantId);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnknownStore_ReturnsNull()
    {
        var command = new CreateStoreAffiliateMappingCommand(
            Guid.NewGuid(), _network.Id, "CL-X", null, null);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateStoreNetworkPair_ThrowsInvalidOperation()
    {
        _mappings.Setup(m => m.StoreNetworkPairExistsAsync(
                _store.Id, _network.Id, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None));
    }

    [Fact]
    public async Task DuplicateExternalMerchantId_ThrowsInvalidOperation()
    {
        _mappings.Setup(m => m.ExternalMerchantIdExistsAsync(
                _network.Id, "CL-MYNTRA", null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None));
    }
}
