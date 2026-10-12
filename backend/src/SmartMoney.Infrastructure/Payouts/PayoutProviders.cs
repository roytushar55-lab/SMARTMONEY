using Microsoft.Extensions.DependencyInjection;
using SmartMoney.Application.Abstractions.Payouts;

namespace SmartMoney.Infrastructure.Payouts;

/// <summary>
/// The catalog of payout providers, keyed by the name used in
/// Payouts:Provider. THIS IS THE ONE PLACE A NEW VENDOR IS REGISTERED:
/// add its adapter class (implementing <see cref="IPayoutProvider"/>) and one
/// line in <see cref="Catalog"/>. See backend/docs/PAYOUT_PROVIDER_GUIDE.md.
/// </summary>
public static class PayoutProviders
{
    public sealed record Entry(
        Func<IServiceProvider, IPayoutProvider> Create,
        bool DevelopmentOnly);

    public static readonly IReadOnlyDictionary<string, Entry> Catalog =
        new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase)
        {
            [ManualPayoutProvider.ProviderName] = new(
                _ => new ManualPayoutProvider(), DevelopmentOnly: false),

            [FakePayoutProvider.ProviderName] = new(
                sp => ActivatorUtilities.CreateInstance<FakePayoutProvider>(sp),
                DevelopmentOnly: true),

            // >>> Register a vendor here, e.g.:
            // ["Razorpay"] = new(
            //     sp => ActivatorUtilities.CreateInstance<RazorpayPayoutProvider>(sp),
            //     DevelopmentOnly: false),
        };

    public static string KnownNames => string.Join(", ", Catalog.Keys);
}
