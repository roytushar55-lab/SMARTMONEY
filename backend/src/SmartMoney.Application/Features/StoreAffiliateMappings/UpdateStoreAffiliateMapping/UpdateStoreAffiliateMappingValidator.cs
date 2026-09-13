namespace SmartMoney.Application.Features.StoreAffiliateMappings.UpdateStoreAffiliateMapping;

public sealed class UpdateStoreAffiliateMappingValidator
{
    public IReadOnlyCollection<string> Validate(UpdateStoreAffiliateMappingCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(command.ExternalMerchantId))
        {
            errors.Add("External merchant id is required.");
        }
        else if (command.ExternalMerchantId.Trim().Length > 200)
        {
            errors.Add("External merchant id must be 200 characters or fewer.");
        }

        return errors;
    }
}
