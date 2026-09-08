using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.StoreAffiliateMappings.UpdateStoreAffiliateMapping;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.StoreAffiliateMappings;

public sealed class UpdateStoreAffiliateMappingHandlerTests
{
    private readonly Mock<IStoreAffiliateMappingRepository> _mappings = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private UpdateStoreAffiliateMappingCommandHandler CreateHandler()
    {
        return new UpdateStoreAffiliateMappingCommandHandler(
            _mappings.Object, new UpdateStoreAffiliateMappingValidator(), _unitOfWork.Object);
    }

    private StoreAffiliateMapping ExistingMapping()
    {
        var store = new Store { Name = "Myntra", Slug = "myntra" };
        var network = new AffiliateNetwork { Name = "Cuelinks", Code = "CUELINKS" };
        var mapping = new StoreAffiliateMapping
        {
            StoreId = store.Id,
            Store = store,
            AffiliateNetworkId = network.Id,
            AffiliateNetwork = network,
            ExternalMerchantId = "CL-OLD",
            IsActive = true
        };

        _mappings.Setup(m => m.GetByIdAsync(mapping.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(mapping);

        return mapping;
    }

    [Fact]
    public async Task ValidRequest_UpdatesFieldsAndDeactivateToggle()
    {
        var mapping = ExistingMapping();

        var response = await CreateHandler().HandleAsync(
            new UpdateStoreAffiliateMappingCommand(
                mapping.Id, "CL-NEW", "Myntra Fashion", "https://myntra.com", false),
            CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("CL-NEW", response!.ExternalMerchantId);
        Assert.False(response.IsActive);
        Assert.NotNull(mapping.UpdatedAt);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnknownMapping_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new UpdateStoreAffiliateMappingCommand(Guid.NewGuid(), "CL-X", null, null, true),
            CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateExternalMerchantIdOnAnotherMapping_ThrowsInvalidOperation()
    {
        var mapping = ExistingMapping();
        _mappings.Setup(m => m.ExternalMerchantIdExistsAsync(
                mapping.AffiliateNetworkId, "CL-TAKEN", mapping.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new UpdateStoreAffiliateMappingCommand(mapping.Id, "CL-TAKEN", null, null, true),
                CancellationToken.None));
    }
}
