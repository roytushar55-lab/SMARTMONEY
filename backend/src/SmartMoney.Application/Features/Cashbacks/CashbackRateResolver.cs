using SmartMoney.Application.Abstractions.CashbackRates;
using SmartMoney.Application.Abstractions.Persistence;

namespace SmartMoney.Application.Features.Cashbacks;

/// <inheritdoc cref="ICashbackRateResolver" />
public sealed class CashbackRateResolver : ICashbackRateResolver
{
    private readonly ICashbackRateOverrideRepository _overrideRepository;
    private readonly INetworkCashbackSettingsRepository _networkSettingsRepository;
    private readonly ICashbackSettingsRepository _systemSettingsRepository;

    public CashbackRateResolver(
        ICashbackRateOverrideRepository overrideRepository,
        INetworkCashbackSettingsRepository networkSettingsRepository,
        ICashbackSettingsRepository systemSettingsRepository)
    {
        _overrideRepository = overrideRepository;
        _networkSettingsRepository = networkSettingsRepository;
        _systemSettingsRepository = systemSettingsRepository;
    }

    public async Task<EffectiveCashbackRate?> ResolveEffectiveRateAsync(
        Guid affiliateNetworkId,
        Guid storeId,
        Guid? categoryId,
        CancellationToken cancellationToken = default)
    {
        // Rung 1: an exact (network, store, category) override, if a
        // category was supplied.
        if (categoryId is Guid category)
        {
            var categoryOverride = await _overrideRepository.GetActiveAsync(
                affiliateNetworkId, storeId, category, cancellationToken);

            if (categoryOverride is not null)
            {
                return new EffectiveCashbackRate(
                    categoryOverride.UserSharePercent,
                    categoryOverride.ConfirmationWindowDays,
                    CashbackRateSource.StoreOverride);
            }
        }

        // Rung 2: a store-wide override (no category) under the network.
        var storeOverride = await _overrideRepository.GetActiveAsync(
            affiliateNetworkId, storeId, null, cancellationToken);

        if (storeOverride is not null)
        {
            return new EffectiveCashbackRate(
                storeOverride.UserSharePercent,
                storeOverride.ConfirmationWindowDays,
                CashbackRateSource.StoreOverride);
        }

        // Rung 3: the network's own global settings.
        var networkSettings = await _networkSettingsRepository.GetByNetworkIdAsync(
            affiliateNetworkId, cancellationToken);

        if (networkSettings is not null)
        {
            return new EffectiveCashbackRate(
                networkSettings.UserSharePercent,
                networkSettings.ConfirmationWindowDays,
                CashbackRateSource.NetworkGlobal);
        }

        // Rung 4: the system-wide fallback.
        var systemSettings = await _systemSettingsRepository.GetAsync(cancellationToken);

        if (systemSettings is not null)
        {
            return new EffectiveCashbackRate(
                systemSettings.UserSharePercent,
                systemSettings.ConfirmationWindowDays,
                CashbackRateSource.SystemGlobal);
        }

        return null;
    }
}
