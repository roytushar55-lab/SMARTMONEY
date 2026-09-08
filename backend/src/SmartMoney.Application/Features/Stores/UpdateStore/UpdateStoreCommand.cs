using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Stores;

namespace SmartMoney.Application.Features.Stores.UpdateStore;

public sealed class UpdateStoreCommand : ICommand<StoreAdminResponse?>
{
    public Guid StoreId { get; }

    public string Name { get; }

    public string Slug { get; }

    public string? ShortDescription { get; }

    public string? Description { get; }

    public string? LogoUrl { get; }

    public string? BannerUrl { get; }

    public string WebsiteUrl { get; }

    public string? DefaultCashbackText { get; }

    public bool IsFeatured { get; }

    public int DisplayOrder { get; }

    public bool IsActive { get; }

    public IReadOnlyList<Guid> CategoryIds { get; }

    public UpdateStoreCommand(
        Guid storeId,
        string name,
        string slug,
        string? shortDescription,
        string? description,
        string? logoUrl,
        string? bannerUrl,
        string websiteUrl,
        string? defaultCashbackText,
        bool isFeatured,
        int displayOrder,
        bool isActive,
        IReadOnlyList<Guid> categoryIds)
    {
        StoreId = storeId;
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
        IsActive = isActive;
        CategoryIds = categoryIds;
    }
}
