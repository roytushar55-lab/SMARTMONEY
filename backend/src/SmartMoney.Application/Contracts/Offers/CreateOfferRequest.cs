namespace SmartMoney.Application.Contracts.Offers;

public sealed class CreateOfferRequest
{
    public Guid StoreId { get; set; }

    public string Title { get; set; } = string.Empty;

    /// <summary>Optional — generated from Title when blank.</summary>
    public string? Slug { get; set; }

    /// <summary>"Cashback", "Coupon", or "Deal".</summary>
    public string OfferType { get; set; } = string.Empty;

    public string? ShortDescription { get; set; }

    public string? Description { get; set; }

    public string? TermsAndConditions { get; set; }

    public string? ImageUrl { get; set; }

    /// <summary>"Percentage", "FlatAmount", "Variable", or "None".</summary>
    public string CashbackType { get; set; } = "None";

    public decimal? CashbackValue { get; set; }

    public string? CashbackText { get; set; }

    public string? CouponCode { get; set; }

    public string DestinationUrl { get; set; } = string.Empty;

    public DateTime? StartAt { get; set; }

    public DateTime? EndAt { get; set; }

    public bool IsFeatured { get; set; }

    public int Priority { get; set; }
}
