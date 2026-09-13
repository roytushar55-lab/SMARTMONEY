namespace SmartMoney.Application.Contracts.Stores;

public sealed class StoreAdminResponse
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string? ShortDescription { get; set; }

    public string? Description { get; set; }

    public string? LogoUrl { get; set; }

    public string? BannerUrl { get; set; }

    public string WebsiteUrl { get; set; } = string.Empty;

    public string? DefaultCashbackText { get; set; }

    public bool IsFeatured { get; set; }

    public int DisplayOrder { get; set; }

    public bool IsActive { get; set; }

    public IReadOnlyList<Guid> CategoryIds { get; set; } = Array.Empty<Guid>();

    public DateTime CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }
}
