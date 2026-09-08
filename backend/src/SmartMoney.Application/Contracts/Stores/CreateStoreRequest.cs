namespace SmartMoney.Application.Contracts.Stores;

public sealed class CreateStoreRequest
{
    public string Name { get; set; } = string.Empty;

    /// <summary>Optional — generated from Name when blank.</summary>
    public string? Slug { get; set; }

    public string? ShortDescription { get; set; }

    public string? Description { get; set; }

    public string? LogoUrl { get; set; }

    public string? BannerUrl { get; set; }

    public string WebsiteUrl { get; set; } = string.Empty;

    public string? DefaultCashbackText { get; set; }

    public bool IsFeatured { get; set; }

    public int DisplayOrder { get; set; }

    public List<Guid> CategoryIds { get; set; } = new();
}
