using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;

namespace SmartMoney.Application.Tests.AffiliateNetworks;

public sealed class CreateAffiliateNetworkHandlerTests
{
    private readonly Mock<IAffiliateNetworkRepository> _networks = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private CreateAffiliateNetworkCommandHandler CreateHandler()
    {
        return new CreateAffiliateNetworkCommandHandler(
            _networks.Object, new CreateAffiliateNetworkValidator(), _unitOfWork.Object);
    }

    [Fact]
    public async Task ValidRequest_CreatesNetworkWithUppercasedCode()
    {
        var response = await CreateHandler().HandleAsync(
            new CreateAffiliateNetworkCommand("Admitad", "admitad"), CancellationToken.None);

        Assert.Equal("Admitad", response.Name);
        Assert.Equal("ADMITAD", response.Code);
        Assert.True(response.IsActive);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task MissingCode_ThrowsArgumentException()
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(
                new CreateAffiliateNetworkCommand("Admitad", ""), CancellationToken.None));

        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateCode_ThrowsInvalidOperation()
    {
        _networks.Setup(n => n.CodeExistsAsync("ADMITAD", null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new CreateAffiliateNetworkCommand("Admitad", "admitad"), CancellationToken.None));
    }
}
