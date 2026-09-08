using SmartMoney.Application.Features.Stores.CreateStore;

namespace SmartMoney.Application.Features.Stores.UpdateStore;

public sealed class UpdateStoreValidator
{
    public IReadOnlyCollection<string> Validate(UpdateStoreCommand command)
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

        if (string.IsNullOrWhiteSpace(command.Slug))
        {
            errors.Add("Slug is required.");
        }
        else if (command.Slug.Trim().Length > 170)
        {
            errors.Add("Slug must be 170 characters or fewer.");
        }

        CreateStoreValidator.ValidateWebsiteUrl(command.WebsiteUrl, errors);

        return errors;
    }
}
