namespace SmartMoney.Application.Contracts.Offers;

public sealed class UpdateOfferRequest
{
    public string Title { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string OfferType { get; set; } = string.Empty;

    public string? ShortDescription { get; set; }

    public string? Description { get; set; }

    public string? TermsAndConditions { get; set; }

    public string? ImageUrl { get; set; }

    public string CashbackType { get; set; } = "None";

    public decimal? CashbackValue { get; set; }

    public string? CashbackText { get; set; }

    public string? CouponCode { get; set; }

    public string DestinationUrl { get; set; } = string.Empty;

    public DateTime? StartAt { get; set; }

    public DateTime? EndAt { get; set; }

    public bool IsFeatured { get; set; }

    public int Priority { get; set; }

    public bool IsActive { get; set; }
}
