using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Offers.UpdateOffer;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Offers;

public sealed class UpdateOfferHandlerTests
{
    private readonly Mock<IOfferRepository> _offers = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    public UpdateOfferHandlerTests()
    {
        _offers.Setup(o => o.GetTrackedByPriorityRangeAsync(
                It.IsAny<int>(), It.IsAny<int>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Offer>());
    }

    private UpdateOfferCommandHandler CreateHandler()
    {
        return new UpdateOfferCommandHandler(
            _offers.Object, new UpdateOfferValidator(), _unitOfWork.Object);
    }

    private Offer ExistingOffer()
    {
        var store = new Store { Name = "Myntra", Slug = "myntra" };
        var offer = new Offer
        {
            StoreId = store.Id,
            Store = store,
            Title = "Old Title",
            Slug = "old-title",
            OfferType = OfferType.Deal,
            DestinationUrl = "https://example.com",
            IsActive = true
        };

        _offers.Setup(o => o.GetByIdAsync(offer.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(offer);

        return offer;
    }

    private static UpdateOfferCommand CommandFor(Offer offer, bool isActive = true)
    {
        return new UpdateOfferCommand(
            offer.Id, "New Title", "new-title", "Cashback", null, null, null, null,
            "Percentage", 15m, "15% back", null, "https://example.com/new",
            null, null, true, 5, isActive);
    }

    [Fact]
    public async Task ValidRequest_UpdatesFieldsAndDeactivateToggle()
    {
        var offer = ExistingOffer();

        var response = await CreateHandler().HandleAsync(
            CommandFor(offer, isActive: false), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("New Title", response!.Title);
        Assert.Equal("Cashback", response.OfferType);
        Assert.False(response.IsActive);
        Assert.NotNull(offer.UpdatedAt);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UnknownOffer_ReturnsNull()
    {
        var command = new UpdateOfferCommand(
            Guid.NewGuid(), "Title", "slug", "Deal", null, null, null, null,
            "None", null, null, null, "https://example.com", null, null, false, 0, true);

        var response = await CreateHandler().HandleAsync(command, CancellationToken.None);

        Assert.Null(response);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateSlugOnAnotherOffer_ThrowsInvalidOperation()
    {
        var offer = ExistingOffer();
        _offers.Setup(o => o.SlugExistsAsync("new-title", offer.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(CommandFor(offer), CancellationToken.None));
    }

    [Fact]
    public async Task MoveForward_ShiftsIntermediateSiblingsBack()
    {
        var offer = ExistingOffer();
        offer.Priority = 0;

        var atOne = new Offer { StoreId = offer.StoreId, Store = offer.Store, Title = "A", Slug = "a", DestinationUrl = "https://a.com", Priority = 1 };
        var atFive = new Offer { StoreId = offer.StoreId, Store = offer.Store, Title = "B", Slug = "b", DestinationUrl = "https://b.com", Priority = 5 };

        _offers.Setup(o => o.GetTrackedByPriorityRangeAsync(
                0, 5, offer.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Offer> { atOne, atFive });

        var response = await CreateHandler().HandleAsync(CommandFor(offer), CancellationToken.None);

        Assert.Equal(5, response!.Priority);
        Assert.Equal(0, atOne.Priority);
        Assert.Equal(4, atFive.Priority);
    }

    [Fact]
    public async Task SameOrder_NoSiblingQueryOrShift()
    {
        var offer = ExistingOffer();
        offer.Priority = 5;

        await CreateHandler().HandleAsync(CommandFor(offer), CancellationToken.None);

        _offers.Verify(
            o => o.GetTrackedByPriorityRangeAsync(
                It.IsAny<int>(), It.IsAny<int>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
