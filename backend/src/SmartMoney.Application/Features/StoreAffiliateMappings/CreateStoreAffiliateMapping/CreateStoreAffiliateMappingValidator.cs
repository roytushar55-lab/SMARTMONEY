namespace SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;

public sealed class CreateStoreAffiliateMappingValidator
{
    public IReadOnlyCollection<string> Validate(CreateStoreAffiliateMappingCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (command.StoreId == Guid.Empty)
        {
            errors.Add("A store is required.");
        }

        if (command.AffiliateNetworkId == Guid.Empty)
        {
            errors.Add("An affiliate network is required.");
        }

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
