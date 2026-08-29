using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SmartMoney.Application.Abstractions.Authentication;

namespace SmartMoney.Infrastructure.Authentication;

/// <summary>
/// Verifies a Google Sign-In ID token via Google's own tokeninfo endpoint
/// rather than a local JWKS/signature check. Google validates the
/// signature, issuer and expiry server-side and simply rejects the request
/// (non-2xx) for anything invalid; this class's own job is the one thing
/// that endpoint doesn't restrict for us — confirming the token's audience
/// matches *our* OAuth client, not some other app's — plus requiring a
/// Google-verified email before the caller is trusted at all.
/// </summary>
public sealed class GoogleIdTokenVerifier : IGoogleIdTokenVerifier
{
    private readonly HttpClient _httpClient;
    private readonly GoogleAuthOptions _options;
    private readonly ILogger<GoogleIdTokenVerifier> _logger;

    public GoogleIdTokenVerifier(
        HttpClient httpClient,
        IOptions<GoogleAuthOptions> options,
        ILogger<GoogleIdTokenVerifier> logger)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<GoogleIdTokenPayload?> VerifyAsync(
        string idToken,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.ClientId))
        {
            _logger.LogWarning(
                "Google sign-in was attempted but no Google OAuth client id is configured.");
            return null;
        }

        if (string.IsNullOrWhiteSpace(idToken))
        {
            return null;
        }

        HttpResponseMessage response;

        try
        {
            response = await _httpClient.GetAsync(
                $"tokeninfo?id_token={Uri.EscapeDataString(idToken)}",
                cancellationToken);
        }
        catch (HttpRequestException exception)
        {
            _logger.LogWarning(
                exception,
                "Could not reach Google to verify a sign-in token.");
            return null;
        }

        if (!response.IsSuccessStatusCode)
        {
            // Invalid, expired, or malformed — Google rejected it outright.
            return null;
        }

        await using var stream =
            await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(
            stream,
            cancellationToken: cancellationToken);
        JsonElement root = document.RootElement;

        string? audience = GetString(root, "aud");

        if (!string.Equals(audience, _options.ClientId, StringComparison.Ordinal))
        {
            _logger.LogWarning(
                "Google id token audience did not match the configured client id.");
            return null;
        }

        string? email = GetString(root, "email");

        if (string.IsNullOrWhiteSpace(email))
        {
            return null;
        }

        string? subject = GetString(root, "sub");

        if (string.IsNullOrWhiteSpace(subject))
        {
            return null;
        }

        bool emailVerified = string.Equals(
            GetString(root, "email_verified"),
            "true",
            StringComparison.OrdinalIgnoreCase);

        string fullName = GetString(root, "name") is { Length: > 0 } name
            ? name
            : email;

        return new GoogleIdTokenPayload(subject, email, emailVerified, fullName);
    }

    // Google's tokeninfo endpoint returns every field as a JSON string
    // (including booleans like "email_verified"), so a plain GetString
    // covers every field we read.
    private static string? GetString(JsonElement root, string property)
    {
        return root.TryGetProperty(property, out JsonElement value)
            ? value.GetString()
            : null;
    }
}
