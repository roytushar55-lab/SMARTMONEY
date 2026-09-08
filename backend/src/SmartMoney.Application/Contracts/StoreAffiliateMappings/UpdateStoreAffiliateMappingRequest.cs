namespace SmartMoney.Application.Contracts.StoreAffiliateMappings;

public sealed class UpdateStoreAffiliateMappingRequest
{
    public string ExternalMerchantId { get; set; } = string.Empty;

    public string? ExternalMerchantName { get; set; }

    public string? MerchantUrl { get; set; }

    public bool IsActive { get; set; }
}
