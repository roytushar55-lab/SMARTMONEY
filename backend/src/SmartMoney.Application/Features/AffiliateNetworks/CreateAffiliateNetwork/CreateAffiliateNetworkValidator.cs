namespace SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;

public sealed class CreateAffiliateNetworkValidator
{
    public IReadOnlyCollection<string> Validate(CreateAffiliateNetworkCommand command)
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

        if (string.IsNullOrWhiteSpace(command.Code))
        {
            errors.Add("Code is required.");
        }
        else if (command.Code.Trim().Length > 50)
        {
            errors.Add("Code must be 50 characters or fewer.");
        }

        return errors;
    }
}
