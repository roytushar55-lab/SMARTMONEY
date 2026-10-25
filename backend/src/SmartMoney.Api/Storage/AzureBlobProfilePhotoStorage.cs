using Azure.Storage.Blobs;
using Microsoft.Extensions.Options;

namespace SmartMoney.Api.Storage;

/// <summary>
/// Profile photos in an Azure Blob container. Deletes are best-effort, as
/// with the Supabase store: a photo that cannot be removed is logged, never
/// surfaced to the user who is replacing it.
/// </summary>
public sealed class AzureBlobProfilePhotoStorage : IProfilePhotoStorage
{
    private readonly AzureBlobObjectStore _store;
    private readonly ILogger<AzureBlobProfilePhotoStorage> _logger;

    public AzureBlobProfilePhotoStorage(
        BlobServiceClient blobServiceClient,
        IOptions<AzureBlobStorageOptions> options,
        ILogger<AzureBlobProfilePhotoStorage> logger)
        : this(
            new AzureBlobObjectStore(
                blobServiceClient.GetBlobContainerClient(
                    options.Value.ProfilePhotosContainer),
                options.Value.PublicBaseUrl,
                options.Value.CacheControlSeconds),
            logger)
    {
    }

    public AzureBlobProfilePhotoStorage(
        AzureBlobObjectStore store,
        ILogger<AzureBlobProfilePhotoStorage> logger)
    {
        _store = store;
        _logger = logger;
    }

    public async Task<StoredProfilePhoto> UploadAsync(
        Stream content,
        string objectPath,
        string contentType,
        CancellationToken cancellationToken)
    {
        (string publicUrl, string storedPath) =
            await _store.UploadAsync(content, objectPath, contentType, cancellationToken);

        return new StoredProfilePhoto(publicUrl, storedPath);
    }

    public async Task DeleteByPublicUrlAsync(
        string? publicUrl,
        CancellationToken cancellationToken)
    {
        if (!_store.TryGetObjectPath(publicUrl, out string? objectPath) ||
            objectPath is null)
        {
            return;
        }

        try
        {
            await _store.DeleteAsync(objectPath, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Azure Blob profile photo cleanup failed for {ObjectPath}.",
                objectPath);
        }
    }
}
