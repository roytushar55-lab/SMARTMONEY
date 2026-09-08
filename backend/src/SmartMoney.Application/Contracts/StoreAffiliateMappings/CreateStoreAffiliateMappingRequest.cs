namespace SmartMoney.Application.Contracts.StoreAffiliateMappings;

public sealed class CreateStoreAffiliateMappingRequest
{
    public Guid StoreId { get; set; }

    public Guid AffiliateNetworkId { get; set; }

    /// <summary>The provider's own id for this merchant (e.g. Cuelinks' "CL-MYNTRA").</summary>
    public string ExternalMerchantId { get; set; } = string.Empty;

    public string? ExternalMerchantName { get; set; }

    public string? MerchantUrl { get; set; }
}
