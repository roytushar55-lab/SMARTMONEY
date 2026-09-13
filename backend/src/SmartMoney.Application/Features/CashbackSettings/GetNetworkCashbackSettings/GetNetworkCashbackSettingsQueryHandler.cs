using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.GetNetworkCashbackSettings;

/// <summary>
/// Null response = the network id does not exist. A network that exists but
/// has no global settings row yet still returns a detail response, just with
/// <c>NetworkSettings</c> null (it falls back to the system-wide row).
/// </summary>
public sealed class GetNetworkCashbackSettingsQueryHandler
    : IQueryHandler<GetNetworkCashbackSettingsQuery, NetworkCashbackSettingsDetailResponse?>
{
    private readonly IAffiliateNetworkRepository _networkRepository;
    private readonly INetworkCashbackSettingsRepository _networkSettingsRepository;
    private readonly ICashbackRateOverrideRepository _overrideRepository;

    public GetNetworkCashbackSettingsQueryHandler(
        IAffiliateNetworkRepository networkRepository,
        INetworkCashbackSettingsRepository networkSettingsRepository,
        ICashbackRateOverrideRepository overrideRepository)
    {
        _networkRepository = networkRepository;
        _networkSettingsRepository = networkSettingsRepository;
        _overrideRepository = overrideRepository;
    }

    public async Task<NetworkCashbackSettingsDetailResponse?> HandleAsync(
        GetNetworkCashbackSettingsQuery query,
        CancellationToken cancellationToken)
    {
        var network = await _networkRepository.GetByIdAsync(query.AffiliateNetworkId, cancellationToken);

        if (network is null)
        {
            return null;
        }

        var settings = await _networkSettingsRepository.GetByNetworkIdAsync(
            query.AffiliateNetworkId, cancellationToken);

        var overrides = await _overrideRepository.ListByNetworkIdAsync(
            query.AffiliateNetworkId, cancellationToken);

        return new NetworkCashbackSettingsDetailResponse
        {
            AffiliateNetworkId = query.AffiliateNetworkId,
            NetworkSettings = settings is null
                ? null
                : ToResponse(settings),
            Overrides = overrides
                .Select(ToOverrideResponse)
                .ToList()
        };
    }

    internal static NetworkCashbackSettingsResponse ToResponse(Domain.Entities.NetworkCashbackSettings settings)
    {
        return new NetworkCashbackSettingsResponse
        {
            AffiliateNetworkId = settings.AffiliateNetworkId,
            UserSharePercent = settings.UserSharePercent,
            ConfirmationWindowDays = settings.ConfirmationWindowDays,
            UpdatedAt = settings.UpdatedAt
        };
    }

    internal static CashbackRateOverrideResponse ToOverrideResponse(Domain.Entities.CashbackRateOverride @override)
    {
        return new CashbackRateOverrideResponse
        {
            Id = @override.Id,
            AffiliateNetworkId = @override.AffiliateNetworkId,
            StoreId = @override.StoreId,
            StoreName = @override.Store.Name,
            CategoryId = @override.CategoryId,
            CategoryName = @override.Category?.Name,
            UserSharePercent = @override.UserSharePercent,
            ConfirmationWindowDays = @override.ConfirmationWindowDays,
            IsActive = @override.IsActive,
            CreatedAt = @override.CreatedAt,
            UpdatedAt = @override.UpdatedAt
        };
    }
}
