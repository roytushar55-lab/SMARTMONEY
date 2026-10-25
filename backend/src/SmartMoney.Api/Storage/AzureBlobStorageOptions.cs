namespace SmartMoney.Api.Storage;

/// <summary>
/// Azure Blob Storage settings, used when <c>Storage:Provider</c> is
/// <c>AzureBlob</c>. Authenticate with either a connection string (simplest;
/// keep it in App Service settings or Key Vault) or an account URL plus the
/// App Service managed identity (no secret at all; grant the identity the
/// "Storage Blob Data Contributor" role on the account).
/// </summary>
public sealed class AzureBlobStorageOptions
{
    public const string SectionName = "AzureBlobStorage";

    /// <summary>Full storage connection string. Wins over <see cref="AccountUrl"/> when set.</summary>
    public string ConnectionString { get; init; } = string.Empty;

    /// <summary>https://&lt;account&gt;.blob.core.windows.net, used with DefaultAzureCredential.</summary>
    public string AccountUrl { get; init; } = string.Empty;

    public string ProfilePhotosContainer { get; init; } = "profile-images";

    public string CatalogueContainer { get; init; } = "catalogue-media";

    /// <summary>
    /// Optional origin to use in the public URLs instead of the account URL,
    /// for a CDN or custom domain in front of the account (no trailing slash).
    /// </summary>
    public string PublicBaseUrl { get; init; } = string.Empty;

    public int CacheControlSeconds { get; init; } = 3600;
}
