using System.Text;
using System.Text.RegularExpressions;

namespace SmartMoney.Application.Common;

/// <summary>
/// Turns a display name into a URL-safe slug when the admin doesn't supply
/// one explicitly (e.g. "Myntra Fashion" -> "myntra-fashion").
/// </summary>
public static class SlugGenerator
{
    public static string Generate(string input)
    {
        string lowered = input.Trim().ToLowerInvariant();

        var builder = new StringBuilder(lowered.Length);
        bool lastWasHyphen = false;

        foreach (char character in lowered)
        {
            if (char.IsLetterOrDigit(character))
            {
                builder.Append(character);
                lastWasHyphen = false;
            }
            else if (!lastWasHyphen && builder.Length > 0)
            {
                builder.Append('-');
                lastWasHyphen = true;
            }
        }

        string slug = builder.ToString().TrimEnd('-');

        return Regex.IsMatch(slug, "[a-z0-9]") ? slug : string.Empty;
    }
}
