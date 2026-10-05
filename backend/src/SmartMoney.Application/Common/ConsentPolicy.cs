namespace SmartMoney.Application.Common;

/// <summary>
/// The Terms/Privacy versions a signup may claim to have accepted. The app
/// sends the version it displayed; the server only records versions it
/// actually knows, so a consent record can always be tied to real text.
/// Add the new version here (keep the old one while old app builds are still
/// in use) whenever the legal documents change.
/// </summary>
public static class ConsentPolicy
{
    public const string CurrentVersion = "2026-10-05";

    // 2026-10-02 stays accepted so app builds that still send the earlier
    // version keep working.
    private static readonly HashSet<string> AcceptedVersions =
        new(StringComparer.Ordinal) { CurrentVersion, "2026-10-02" };

    public static bool IsAccepted(string? version)
    {
        return version is not null && AcceptedVersions.Contains(version.Trim());
    }
}
