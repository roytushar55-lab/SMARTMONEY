namespace SmartMoney.Api.Storage;

/// <summary>
/// Blob storage for admin-uploaded catalogue images (store logos/banners,
/// offer images, category icons) — separate bucket from profile photos.
/// </summary>
public interface ICatalogueMediaStorage
{
    Task<StoredCatalogueMedia> UploadAsync(
        Stream content,
        string objectPath,
        string contentType,
        CancellationToken cancellationToken);
}

public sealed record StoredCatalogueMedia(
    string PublicUrl,
    string ObjectPath);
