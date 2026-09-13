namespace SmartMoney.Application.Contracts.CashbackSettings;

/// <summary>
/// Response for the admin network detail screen: the network's own global
/// settings (null when unset — it falls back to the system-wide settings)
/// plus every store/category override configured for it.
/// </summary>
public sealed class NetworkCashbackSettingsDetailResponse
{
    public Guid AffiliateNetworkId { get; set; }

    public NetworkCashbackSettingsResponse? NetworkSettings { get; set; }

    public IReadOnlyList<CashbackRateOverrideResponse> Overrides { get; set; }
        = new List<CashbackRateOverrideResponse>();
}
