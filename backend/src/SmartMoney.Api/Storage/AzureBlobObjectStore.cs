using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace SmartMoney.Api.Storage;

/// <summary>
/// The one place that talks to an Azure Blob container: upload with the
/// right headers, build the public URL, and map a public URL back to the
/// blob path for deletes. Both media stores are thin wrappers over it.
/// Containers are expected to allow anonymous blob reads (public access
/// level "Blob"); the provisioning script creates them that way.
/// </summary>
public sealed class AzureBlobObjectStore
{
    private readonly BlobContainerClient _container;
    private readonly string _publicPrefix;
    private readonly string _cacheControl;

    public AzureBlobObjectStore(
        BlobContainerClient container,
        string? publicBaseUrl,
        int cacheControlSeconds)
    {
        _container = container;

        string prefix = string.IsNullOrWhiteSpace(publicBaseUrl)
            ? container.Uri.ToString()
            : $"{publicBaseUrl.TrimEnd('/')}/{container.Name}";

        _publicPrefix = prefix.TrimEnd('/') + "/";
        _cacheControl = $"public, max-age={Math.Max(0, cacheControlSeconds)}";
    }

    /// <summary>
    /// Uploads (or overwrites) the blob and returns its public URL and the
    /// normalised blob path.
    /// </summary>
    public async Task<(string PublicUrl, string ObjectPath)> UploadAsync(
        Stream content,
        string objectPath,
        string contentType,
        CancellationToken cancellationToken)
    {
        string normalizedPath = NormalizeObjectPath(objectPath);
        BlobClient blob = _container.GetBlobClient(normalizedPath);

        var options = new BlobUploadOptions
        {
            HttpHeaders = new BlobHttpHeaders
            {
                ContentType = contentType,
                CacheControl = _cacheControl
            }
        };

        await blob.UploadAsync(content, options, cancellationToken);

        return (BuildPublicUrl(normalizedPath), normalizedPath);
    }

    /// <summary>Deletes the blob if it exists; a missing blob is not an error.</summary>
    public Task DeleteAsync(string objectPath, CancellationToken cancellationToken)
    {
        return _container.DeleteBlobIfExistsAsync(
            NormalizeObjectPath(objectPath),
            cancellationToken: cancellationToken);
    }

    public string BuildPublicUrl(string objectPath)
    {
        string encodedPath = string.Join(
            "/",
            NormalizeObjectPath(objectPath)
                .Split('/', StringSplitOptions.RemoveEmptyEntries)
                .Select(Uri.EscapeDataString));

        return _publicPrefix + encodedPath;
    }

    /// <summary>
    /// True when <paramref name="publicUrl"/> points into this container;
    /// <paramref name="objectPath"/> is then the decoded blob path. URLs from
    /// anywhere else (an old Supabase URL, another container) return false so
    /// callers never delete something they do not own.
    /// </summary>
    public bool TryGetObjectPath(string? publicUrl, out string? objectPath)
    {
        objectPath = null;

        if (string.IsNullOrWhiteSpace(publicUrl) ||
            !publicUrl.StartsWith(_publicPrefix, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        string remainder = publicUrl[_publicPrefix.Length..];

        int queryStart = remainder.IndexOfAny(['?', '#']);
        if (queryStart >= 0)
        {
            remainder = remainder[..queryStart];
        }

        string decoded = Uri.UnescapeDataString(remainder);

        if (string.IsNullOrWhiteSpace(decoded))
        {
            return false;
        }

        objectPath = decoded;
        return true;
    }

    private static string NormalizeObjectPath(string objectPath)
    {
        string normalized = objectPath.Trim().Replace('\\', '/').TrimStart('/');

        if (string.IsNullOrWhiteSpace(normalized))
        {
            throw new ArgumentException(
                "Object path is required.",
                nameof(objectPath));
        }

        return normalized;
    }
}
