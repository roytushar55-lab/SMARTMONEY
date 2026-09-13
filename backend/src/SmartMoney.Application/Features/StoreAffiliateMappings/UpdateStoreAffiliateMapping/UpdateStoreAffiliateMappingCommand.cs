using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;

namespace SmartMoney.Application.Features.StoreAffiliateMappings.UpdateStoreAffiliateMapping;

public sealed class UpdateStoreAffiliateMappingCommand : ICommand<StoreAffiliateMappingAdminResponse?>
{
    public Guid MappingId { get; }

    public string ExternalMerchantId { get; }

    public string? ExternalMerchantName { get; }

    public string? MerchantUrl { get; }

    public bool IsActive { get; }

    public UpdateStoreAffiliateMappingCommand(
        Guid mappingId,
        string externalMerchantId,
        string? externalMerchantName,
        string? merchantUrl,
        bool isActive)
    {
        MappingId = mappingId;
        ExternalMerchantId = externalMerchantId;
        ExternalMerchantName = externalMerchantName;
        MerchantUrl = merchantUrl;
        IsActive = isActive;
    }
}
