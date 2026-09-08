using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Offers.CreateOffer;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Offers;

public sealed class CreateOfferHandlerTests
{
    private readonly Mock<IOfferRepository> _offers = new();
    private readonly Mock<IStoreRepository> _stores = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private readonly Store _store = new() { Name = "Myntra", Slug = "myntra" };

    public CreateOfferHandlerTests()
    {
        _stores.Setup(s => s.GetByIdAsync(_store.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_store);
    }

    private CreateOfferCommandHandler CreateHandler()
    {
        return new CreateOfferCommandHandler(
            _offers.Object, _stores.Object, new CreateOfferValidator(), _unitOfWork.Object);
    }

    private CreateOfferCommand ValidCommand(string offerType = "Cashback", string cashbackType = "Percentage")
    {
        return new CreateOfferCommand(
            _store.Id, "10% Off Fashion", null, offerType, "short", "long", "terms",
            null, cashbackType, 10m, "10% cashback", null,
            "https://www.myntra.com/sale", null, null, true, 1);
    }

    [Fact]
    public async Task ValidRequest_CreatesOfferWithGeneratedSlug()
    {
        var response = await CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("10-off-fashion", response!.Slug);
        Assert.Equal("Myntra", response.StoreName);
        Assert.Equal("Cashback", response.OfferType);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnknownStore_ReturnsNull()
    {
        var command = new CreateOfferCommand(
            Guid.NewGuid(), "Title", null, "Cashback", null, null, null, null,
            "None", null, null, null, "https://example.com", null, null, false, 0);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task InvalidOfferType_ThrowsArgumentException()
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(ValidCommand(offerType: "NotARealType"), CancellationToken.None));
    }

    [Fact]
    public async Task EndBeforeStart_ThrowsArgumentException()
    {
        var command = new CreateOfferCommand(
            _store.Id, "Title", null, "Deal", null, null, null, null,
            "None", null, null, null, "https://example.com",
            DateTime.UtcNow, DateTime.UtcNow.AddDays(-1), false, 0);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(command, CancellationToken.None));
    }

    [Fact]
    public async Task DuplicateSlug_ThrowsInvalidOperation()
    {
        _offers.Setup(o => o.SlugExistsAsync("10-off-fashion", null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(ValidCommand(), CancellationToken.None));
    }
}
