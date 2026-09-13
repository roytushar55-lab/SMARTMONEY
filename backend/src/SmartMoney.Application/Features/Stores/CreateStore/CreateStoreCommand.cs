using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Stores;

namespace SmartMoney.Application.Features.Stores.CreateStore;

public sealed class CreateStoreCommand : ICommand<StoreAdminResponse>
{
    public string Name { get; }

    public string? Slug { get; }

    public string? ShortDescription { get; }

    public string? Description { get; }

    public string? LogoUrl { get; }

    public string? BannerUrl { get; }

    public string WebsiteUrl { get; }

    public string? DefaultCashbackText { get; }

    public bool IsFeatured { get; }

    public int DisplayOrder { get; }

    public IReadOnlyList<Guid> CategoryIds { get; }

    public CreateStoreCommand(
        string name,
        string? slug,
        string? shortDescription,
        string? description,
        string? logoUrl,
        string? bannerUrl,
        string websiteUrl,
        string? defaultCashbackText,
        bool isFeatured,
        int displayOrder,
        IReadOnlyList<Guid> categoryIds)
    {
        Name = name;
        Slug = slug;
        ShortDescription = shortDescription;
        Description = description;
        LogoUrl = logoUrl;
        BannerUrl = bannerUrl;
        WebsiteUrl = websiteUrl;
        DefaultCashbackText = defaultCashbackText;
        IsFeatured = isFeatured;
        DisplayOrder = displayOrder;
        CategoryIds = categoryIds;
    }
}
