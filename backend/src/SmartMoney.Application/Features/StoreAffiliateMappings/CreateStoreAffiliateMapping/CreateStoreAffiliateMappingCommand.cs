using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;

namespace SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;

public sealed class CreateStoreAffiliateMappingCommand : ICommand<StoreAffiliateMappingAdminResponse?>
{
    public Guid StoreId { get; }

    public Guid AffiliateNetworkId { get; }

    public string ExternalMerchantId { get; }

    public string? ExternalMerchantName { get; }

    public string? MerchantUrl { get; }

    public CreateStoreAffiliateMappingCommand(
        Guid storeId,
        Guid affiliateNetworkId,
        string externalMerchantId,
        string? externalMerchantName,
        string? merchantUrl)
    {
        StoreId = storeId;
        AffiliateNetworkId = affiliateNetworkId;
        ExternalMerchantId = externalMerchantId;
        ExternalMerchantName = externalMerchantName;
        MerchantUrl = merchantUrl;
    }
}
