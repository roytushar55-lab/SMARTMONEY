namespace SmartMoney.Infrastructure.Authentication;

public sealed class GoogleAuthOptions
{
    public const string SectionName = "GoogleAuth";

    /// <summary>
    /// The Web application OAuth 2.0 Client ID from Google Cloud Console.
    /// Not a secret — Google Sign-In client ids are safe to ship in the
    /// frontend too — but a token whose audience doesn't match this value
    /// was issued for a different app and must be rejected.
    /// </summary>
    public string ClientId { get; init; } = string.Empty;
}
