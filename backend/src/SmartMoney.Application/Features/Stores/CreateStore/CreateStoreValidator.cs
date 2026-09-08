namespace SmartMoney.Application.Features.Stores.CreateStore;

public sealed class CreateStoreValidator
{
    public IReadOnlyCollection<string> Validate(CreateStoreCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(command.Name))
        {
            errors.Add("Name is required.");
        }
        else if (command.Name.Trim().Length > 150)
        {
            errors.Add("Name must be 150 characters or fewer.");
        }

        if (!string.IsNullOrWhiteSpace(command.Slug) && command.Slug.Trim().Length > 170)
        {
            errors.Add("Slug must be 170 characters or fewer.");
        }

        ValidateWebsiteUrl(command.WebsiteUrl, errors);

        return errors;
    }

    internal static void ValidateWebsiteUrl(string websiteUrl, ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(websiteUrl))
        {
            errors.Add("Website URL is required.");
            return;
        }

        if (!Uri.TryCreate(websiteUrl, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            errors.Add("Website URL must be a valid http(s) URL.");
        }
    }
}
