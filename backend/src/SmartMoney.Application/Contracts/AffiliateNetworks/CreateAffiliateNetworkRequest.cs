namespace SmartMoney.Application.Contracts.AffiliateNetworks;

public sealed class CreateAffiliateNetworkRequest
{
    public string Name { get; set; } = string.Empty;

    /// <summary>Provider code used to resolve inbound webhooks (e.g. "CUELINKS").</summary>
    public string Code { get; set; } = string.Empty;
}
