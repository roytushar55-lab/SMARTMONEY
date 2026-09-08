namespace SmartMoney.Application.Contracts.AffiliateNetworks;

public sealed class UpdateAffiliateNetworkRequest
{
    public string Name { get; set; } = string.Empty;

    public string Code { get; set; } = string.Empty;

    public bool IsActive { get; set; }
}
