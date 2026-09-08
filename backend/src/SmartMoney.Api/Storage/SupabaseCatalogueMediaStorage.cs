using System.Net.Http.Headers;
using Microsoft.Extensions.Options;

namespace SmartMoney.Api.Storage;

/// <summary>
/// Same Supabase Storage REST calls as <see cref="SupabaseProfilePhotoStorage"/>,
/// pointed at the catalogue bucket instead — kept independent rather than
/// sharing code so the working profile-photo path is never at risk from
/// catalogue-media changes.
/// </summary>
public sealed class SupabaseCatalogueMediaStorage : ICatalogueMediaStorage
{
    private readonly HttpClient _httpClient;
    private readonly SupabaseStorageOptions _options;

    public SupabaseCatalogueMediaStorage(
        HttpClient httpClient,
        IOptions<SupabaseStorageOptions> options)
    {
        _httpClient = httpClient;
        _options = options.Value;
    }

    public async Task<StoredCatalogueMedia> UploadAsync(
        Stream content,
        string objectPath,
        string contentType,
        CancellationToken cancellationToken)
    {
        ValidateOptions();

        string normalizedPath = NormalizeObjectPath(objectPath);
        Uri uploadUri = BuildObjectUri(normalizedPath, isPublic: false);

        using var request = new HttpRequestMessage(HttpMethod.Post, uploadUri);
        AddAuthenticationHeaders(request);
        request.Headers.TryAddWithoutValidation(
            "cache-control",
            _options.CacheControlSeconds.ToString());

        request.Content = new StreamContent(content);
        request.Content.Headers.ContentType =
            MediaTypeHeaderValue.Parse(contentType);

        using HttpResponseMessage response =
            await _httpClient.SendAsync(request, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            string responseBody =
                await response.Content.ReadAsStringAsync(cancellationToken);

            throw new InvalidOperationException(
                "Supabase catalogue media upload failed with status " +
                $"{(int)response.StatusCode}: {responseBody}");
        }

        return new StoredCatalogueMedia(
            BuildObjectUri(normalizedPath, isPublic: true).ToString(),
            normalizedPath);
    }

    private void AddAuthenticationHeaders(HttpRequestMessage request)
    {
        request.Headers.TryAddWithoutValidation(
            "apikey",
            _options.ServiceRoleKey);

        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            _options.ServiceRoleKey);
    }

    private Uri BuildObjectUri(string objectPath, bool isPublic)
    {
        string encodedPath = string.Join(
            "/",
            objectPath
                .Split('/', StringSplitOptions.RemoveEmptyEntries)
                .Select(Uri.EscapeDataString));

        string visibilitySegment = isPublic ? "/public" : string.Empty;
        string url = _options.Url.TrimEnd('/');

        return new Uri(
            $"{url}/storage/v1/object{visibilitySegment}/" +
            $"{Uri.EscapeDataString(_options.CatalogueBucket)}/{encodedPath}");
    }

    private void ValidateOptions()
    {
        if (string.IsNullOrWhiteSpace(_options.Url))
        {
            throw new InvalidOperationException(
                "Supabase Storage URL is not configured.");
        }

        if (string.IsNullOrWhiteSpace(_options.ServiceRoleKey))
        {
            throw new InvalidOperationException(
                "Supabase Storage service role key is not configured.");
        }

        if (string.IsNullOrWhiteSpace(_options.CatalogueBucket))
        {
            throw new InvalidOperationException(
                "Supabase Storage catalogue bucket is not configured.");
        }
    }

    private static string NormalizeObjectPath(string objectPath)
    {
        string normalized = objectPath.Trim().Replace('\\', '/');

        if (string.IsNullOrWhiteSpace(normalized))
        {
            throw new ArgumentException(
                "Object path is required.",
                nameof(objectPath));
        }

        return normalized.TrimStart('/');
    }
}
