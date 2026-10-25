using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SmartMoney.Application.Abstractions.Affiliate;

namespace SmartMoney.Infrastructure.Affiliate;

/// <summary>
/// Cuelinks Publisher API (V3) client. Registered instead of the mock only
/// when an API key is configured.
///
/// Link conversion uses <c>POST {BaseUrl}/links/convert</c> with the
/// merchant URL and our click's tracking reference as <c>subid</c>. Cuelinks
/// echoes that sub ID back as <c>aff_sub</c> on every transaction postback,
/// which is how a sale is matched to the user who tapped "Earn cashback".
///
/// Any failure (timeout, non-2xx, unreadable reply) returns null so the
/// caller falls back to the untracked store link: the user still reaches the
/// store, and the failure is logged for the team to fix.
/// </summary>
public sealed class CuelinksAffiliateNetworkClient : IAffiliateNetworkClient
{
    private readonly HttpClient _httpClient;
    private readonly CuelinksOptions _options;
    private readonly ILogger<CuelinksAffiliateNetworkClient> _logger;

    public CuelinksAffiliateNetworkClient(
        HttpClient httpClient,
        IOptions<CuelinksOptions> options,
        ILogger<CuelinksAffiliateNetworkClient> logger)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _logger = logger;

        // Trailing slash so the relative "links/convert" keeps the /pub_api/v3 path.
        _httpClient.BaseAddress = new Uri(_options.BaseUrl.TrimEnd('/') + "/");
        _httpClient.Timeout = TimeSpan.FromSeconds(Math.Clamp(_options.TimeoutSeconds, 1, 60));

        // Cuelinks' scheme is literally "Token", not "Bearer".
        _httpClient.DefaultRequestHeaders.TryAddWithoutValidation(
            "Authorization", $"Token {_options.ApiKey}");
    }

    public async Task<string?> BuildTrackedUrlAsync(
        string destinationUrl,
        string trackingReference,
        CancellationToken cancellationToken = default)
    {
        var request = new ConvertLinkRequest(
            destinationUrl,
            trackingReference,
            _options.ChannelId);

        try
        {
            using HttpResponseMessage response = await _httpClient.PostAsJsonAsync(
                "links/convert", request, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                string body = await response.Content.ReadAsStringAsync(cancellationToken);

                _logger.LogWarning(
                    "Cuelinks link conversion failed with {Status} for {Url}: {Body}",
                    (int)response.StatusCode,
                    destinationUrl,
                    Truncate(body, 500));

                return null;
            }

            var parsed = await response.Content.ReadFromJsonAsync<ConvertLinkResponse>(
                cancellationToken: cancellationToken);

            string? trackingUrl = parsed?.Data?.TrackingUrl;

            if (!Uri.TryCreate(trackingUrl, UriKind.Absolute, out Uri? uri) ||
                (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp))
            {
                _logger.LogWarning(
                    "Cuelinks returned no usable tracking_url for {Url}.", destinationUrl);

                return null;
            }

            if (parsed!.Data!.Affiliated == false)
            {
                // Still a working redirect, but the campaign is inactive, not
                // found, or needs approval: no commission until that is fixed.
                _logger.LogWarning(
                    "Cuelinks link for {Url} is not affiliated (campaign {Campaign}); purchases will not earn commission.",
                    destinationUrl,
                    parsed.Data.Campaign?.Name ?? "none");
            }

            return trackingUrl;
        }
        catch (Exception exception) when (
            exception is HttpRequestException or JsonException or NotSupportedException ||
            (exception is TaskCanceledException && !cancellationToken.IsCancellationRequested))
        {
            _logger.LogWarning(
                exception,
                "Cuelinks link conversion failed for {Url}; falling back to the untracked link.",
                destinationUrl);

            return null;
        }
    }

    private static string Truncate(string value, int max) =>
        value.Length <= max ? value : value[..max];

    private sealed record ConvertLinkRequest(
        [property: JsonPropertyName("url")] string Url,
        [property: JsonPropertyName("subid")] string SubId,
        [property: JsonPropertyName("channel_id"),
                   JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] int? ChannelId);

    private sealed record ConvertLinkResponse(
        [property: JsonPropertyName("data")] ConvertLinkData? Data);

    private sealed record ConvertLinkData(
        [property: JsonPropertyName("tracking_url")] string? TrackingUrl,
        [property: JsonPropertyName("affiliated")] bool? Affiliated,
        [property: JsonPropertyName("campaign")] ConvertLinkCampaign? Campaign);

    private sealed record ConvertLinkCampaign(
        [property: JsonPropertyName("id")] long? Id,
        [property: JsonPropertyName("name")] string? Name);
}
