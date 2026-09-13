namespace SmartMoney.Application.Abstractions.CashbackRates;

/// <summary>
/// The resolved user share/confirmation window for one cashback, plus which
/// rung of the hierarchy supplied it — useful for admin diagnostics/logging.
/// </summary>
public readonly record struct EffectiveCashbackRate(
    decimal UserSharePercent,
    int ConfirmationWindowDays,
    CashbackRateSource Source);

public enum CashbackRateSource
{
    StoreOverride,
    NetworkGlobal,
    SystemGlobal
}

/// <summary>
/// Resolves the cashback rate that applies to one conversion by walking the
/// 3-level hierarchy from most to least specific: a
/// <c>CashbackRateOverride</c> for the store (optionally narrowed to a
/// category) under the network, then that network's
/// <c>NetworkCashbackSettings</c>, then the system-wide
/// <c>CashbackSettings</c> singleton. Returns null only when none of the
/// three rungs has a usable row (should not happen once the system row is
/// seeded).
/// </summary>
public interface ICashbackRateResolver
{
    Task<EffectiveCashbackRate?> ResolveEffectiveRateAsync(
        Guid affiliateNetworkId,
        Guid storeId,
        Guid? categoryId,
        CancellationToken cancellationToken = default);
}
