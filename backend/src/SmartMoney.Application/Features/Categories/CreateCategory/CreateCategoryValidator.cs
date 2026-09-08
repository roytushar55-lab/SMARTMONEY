namespace SmartMoney.Application.Features.Categories.CreateCategory;

public sealed class CreateCategoryValidator
{
    public IReadOnlyCollection<string> Validate(CreateCategoryCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(command.Name))
        {
            errors.Add("Name is required.");
        }
        else if (command.Name.Trim().Length > 100)
        {
            errors.Add("Name must be 100 characters or fewer.");
        }

        if (!string.IsNullOrWhiteSpace(command.Slug) && command.Slug.Trim().Length > 120)
        {
            errors.Add("Slug must be 120 characters or fewer.");
        }

        if (!string.IsNullOrWhiteSpace(command.Description) &&
            command.Description.Trim().Length > 500)
        {
            errors.Add("Description must be 500 characters or fewer.");
        }

        return errors;
    }
}
