using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.AffiliateNetworks.UpdateAffiliateNetwork;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.AffiliateNetworks;

public sealed class UpdateAffiliateNetworkHandlerTests
{
    private readonly Mock<IAffiliateNetworkRepository> _networks = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private UpdateAffiliateNetworkCommandHandler CreateHandler()
    {
        return new UpdateAffiliateNetworkCommandHandler(
            _networks.Object, new UpdateAffiliateNetworkValidator(), _unitOfWork.Object);
    }

    [Fact]
    public async Task ValidRequest_UpdatesAndDeactivateToggle()
    {
        var network = new AffiliateNetwork { Name = "Cuelinks", Code = "CUELINKS" };
        _networks.Setup(n => n.GetByIdAsync(network.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(network);

        var response = await CreateHandler().HandleAsync(
            new UpdateAffiliateNetworkCommand(network.Id, "Cuelinks India", "CUELINKS", false),
            CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("Cuelinks India", response!.Name);
        Assert.False(response.IsActive);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnknownNetwork_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new UpdateAffiliateNetworkCommand(Guid.NewGuid(), "Name", "CODE", true),
            CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
