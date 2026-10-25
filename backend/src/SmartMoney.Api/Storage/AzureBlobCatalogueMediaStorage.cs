using Azure.Storage.Blobs;
using Microsoft.Extensions.Options;

namespace SmartMoney.Api.Storage;

/// <summary>
/// Admin-uploaded catalogue images (store logos and banners, offer images,
/// category icons) in their own Azure Blob container.
/// </summary>
public sealed class AzureBlobCatalogueMediaStorage : ICatalogueMediaStorage
{
    private readonly AzureBlobObjectStore _store;

    public AzureBlobCatalogueMediaStorage(
        BlobServiceClient blobServiceClient,
        IOptions<AzureBlobStorageOptions> options)
        : this(
            new AzureBlobObjectStore(
                blobServiceClient.GetBlobContainerClient(
                    options.Value.CatalogueContainer),
                options.Value.PublicBaseUrl,
                options.Value.CacheControlSeconds))
    {
    }

    public AzureBlobCatalogueMediaStorage(AzureBlobObjectStore store)
    {
        _store = store;
    }

    public async Task<StoredCatalogueMedia> UploadAsync(
        Stream content,
        string objectPath,
        string contentType,
        CancellationToken cancellationToken)
    {
        (string publicUrl, string storedPath) =
            await _store.UploadAsync(content, objectPath, contentType, cancellationToken);

        return new StoredCatalogueMedia(publicUrl, storedPath);
    }
}
