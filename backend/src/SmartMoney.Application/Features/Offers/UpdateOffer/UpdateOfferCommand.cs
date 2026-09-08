using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Offers;

namespace SmartMoney.Application.Features.Offers.UpdateOffer;

public sealed class UpdateOfferCommand : ICommand<OfferAdminResponse?>
{
    public Guid OfferId { get; }

    public string Title { get; }

    public string Slug { get; }

    public string OfferType { get; }

    public string? ShortDescription { get; }

    public string? Description { get; }

    public string? TermsAndConditions { get; }

    public string? ImageUrl { get; }

    public string CashbackType { get; }

    public decimal? CashbackValue { get; }

    public string? CashbackText { get; }

    public string? CouponCode { get; }

    public string DestinationUrl { get; }

    public DateTime? StartAt { get; }

    public DateTime? EndAt { get; }

    public bool IsFeatured { get; }

    public int Priority { get; }

    public bool IsActive { get; }

    public UpdateOfferCommand(
        Guid offerId,
        string title,
        string slug,
        string offerType,
        string? shortDescription,
        string? description,
        string? termsAndConditions,
        string? imageUrl,
        string cashbackType,
        decimal? cashbackValue,
        string? cashbackText,
        string? couponCode,
        string destinationUrl,
        DateTime? startAt,
        DateTime? endAt,
        bool isFeatured,
        int priority,
        bool isActive)
    {
        OfferId = offerId;
        Title = title;
        Slug = slug;
        OfferType = offerType;
        ShortDescription = shortDescription;
        Description = description;
        TermsAndConditions = termsAndConditions;
        ImageUrl = imageUrl;
        CashbackType = cashbackType;
        CashbackValue = cashbackValue;
        CashbackText = cashbackText;
        CouponCode = couponCode;
        DestinationUrl = destinationUrl;
        StartAt = startAt;
        EndAt = endAt;
        IsFeatured = isFeatured;
        Priority = priority;
        IsActive = isActive;
    }
}
