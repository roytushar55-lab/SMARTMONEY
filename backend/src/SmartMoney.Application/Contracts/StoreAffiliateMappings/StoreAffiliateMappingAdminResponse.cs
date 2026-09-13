namespace SmartMoney.Application.Contracts.StoreAffiliateMappings;

public sealed class StoreAffiliateMappingAdminResponse
{
    public Guid Id { get; set; }

    public Guid StoreId { get; set; }

    public string StoreName { get; set; } = string.Empty;

    public Guid AffiliateNetworkId { get; set; }

    public string AffiliateNetworkName { get; set; } = string.Empty;

    public string ExternalMerchantId { get; set; } = string.Empty;

    public string? ExternalMerchantName { get; set; }

    public string? MerchantUrl { get; set; }

    public bool IsActive { get; set; }

    public DateTime? LastSyncedAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }
}
