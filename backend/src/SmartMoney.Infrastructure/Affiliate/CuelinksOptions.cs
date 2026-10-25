namespace SmartMoney.Infrastructure.Affiliate;

/// <summary>
/// Cuelinks Publisher API (V3) settings. See developers.cuelinks.com.
/// </summary>
public sealed class CuelinksOptions
{
    public const string SectionName = "AffiliateNetworks:Cuelinks";

    /// <summary>
    /// V3 API key with at least the <c>write:links</c> scope. Empty (the
    /// default) keeps the mock network client registered; setting a key
    /// switches DI to <see cref="CuelinksAffiliateNetworkClient"/>. Comes from
    /// User Secrets or App Service settings, never from a tracked config file.
    /// </summary>
    public string ApiKey { get; init; } = string.Empty;

    /// <summary>
    /// Base of the Publisher API, as given in the Cuelinks developer docs.
    /// </summary>
    public string BaseUrl { get; init; } = "https://developers.cuelinks.com/pub_api/v3";

    /// <summary>
    /// Cuelinks channel the clicks are attributed to (the SmartMoney app's
    /// channel). Optional: when unset, Cuelinks uses the account's default
    /// channel.
    /// </summary>
    public int? ChannelId { get; init; }

    /// <summary>
    /// How long to wait for Cuelinks before falling back to the untracked
    /// store link, so a slow network never blocks the user's tap for long.
    /// </summary>
    public int TimeoutSeconds { get; init; } = 8;
}
