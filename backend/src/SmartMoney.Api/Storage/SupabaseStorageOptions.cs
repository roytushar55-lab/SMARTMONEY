namespace SmartMoney.Api.Storage;

public sealed class SupabaseStorageOptions
{
    public const string SectionName = "SupabaseStorage";

    public string Url { get; init; } = string.Empty;

    public string ServiceRoleKey { get; init; } = string.Empty;

    public string Bucket { get; init; } = "profile-images";

    /// <summary>Bucket for store logos/banners and offer images (admin panel).</summary>
    public string CatalogueBucket { get; init; } = "catalogue-media";

    public int CacheControlSeconds { get; init; } = 3600;
}
