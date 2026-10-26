using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Options;

namespace SmartMoney.Api.Storage;

/// <summary>
/// Chooses where uploaded images live from <c>Storage:Provider</c>:
/// <c>Supabase</c> (the original setup, default) or <c>AzureBlob</c>.
/// A wrong or incomplete setting is a startup error, not a failed upload
/// on the first user's photo.
/// </summary>
public static class MediaStorageRegistration
{
    public const string SupabaseProvider = "Supabase";
    public const string AzureBlobProvider = "AzureBlob";

    public static IServiceCollection AddMediaStorage(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        string provider = configuration["Storage:Provider"] ?? SupabaseProvider;

        switch (provider)
        {
            case SupabaseProvider:
                services.Configure<SupabaseStorageOptions>(
                    configuration.GetSection(SupabaseStorageOptions.SectionName));
                services.AddHttpClient<IProfilePhotoStorage, SupabaseProfilePhotoStorage>();
                services.AddHttpClient<ICatalogueMediaStorage, SupabaseCatalogueMediaStorage>();
                return services;

            case AzureBlobProvider:
                var azureOptions = configuration
                    .GetSection(AzureBlobStorageOptions.SectionName)
                    .Get<AzureBlobStorageOptions>() ?? new AzureBlobStorageOptions();

                Validate(azureOptions);

                services.Configure<AzureBlobStorageOptions>(
                    configuration.GetSection(AzureBlobStorageOptions.SectionName));

                services.AddSingleton(serviceProvider =>
                    CreateBlobServiceClient(
                        serviceProvider.GetRequiredService<IOptions<AzureBlobStorageOptions>>().Value));

                services.AddSingleton<IProfilePhotoStorage, AzureBlobProfilePhotoStorage>();
                services.AddSingleton<ICatalogueMediaStorage, AzureBlobCatalogueMediaStorage>();
                return services;

            default:
                throw new InvalidOperationException(
                    $"Storage:Provider '{provider}' is not known. " +
                    $"Use '{SupabaseProvider}' or '{AzureBlobProvider}'.");
        }
    }

    private static void Validate(AzureBlobStorageOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.ConnectionString) &&
            string.IsNullOrWhiteSpace(options.AccountUrl))
        {
            throw new InvalidOperationException(
                "Storage:Provider is AzureBlob but neither " +
                "BlobStorage:ConnectionString nor BlobStorage:AccountUrl is set.");
        }

        if (string.IsNullOrWhiteSpace(options.ProfilePhotosContainer) ||
            string.IsNullOrWhiteSpace(options.CatalogueContainer))
        {
            throw new InvalidOperationException(
                "BlobStorage:ProfilePhotosContainer and " +
                "BlobStorage:CatalogueContainer must both be set.");
        }
    }

    private static BlobServiceClient CreateBlobServiceClient(AzureBlobStorageOptions options)
    {
        if (!string.IsNullOrWhiteSpace(options.ConnectionString))
        {
            return new BlobServiceClient(options.ConnectionString);
        }

        // Managed identity on App Service; developer sign-in (az login,
        // Visual Studio) locally. No secret to rotate or leak.
        return new BlobServiceClient(
            new Uri(options.AccountUrl),
            new DefaultAzureCredential());
    }
}
