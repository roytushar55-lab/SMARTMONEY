using SmartMoney.Application.Abstractions.Payouts;

namespace SmartMoney.Infrastructure.Payouts;

/// <summary>
/// The "no vendor yet" provider. Nothing is sent anywhere: an admin pays the
/// user by bank or UPI app, then records the bank reference through the admin
/// API. Because <see cref="SupportsAutomaticPayout"/> is false the background
/// worker never touches these withdrawals.
/// </summary>
public sealed class ManualPayoutProvider : IPayoutProvider
{
    public const string ProviderName = "Manual";

    public string Name => ProviderName;

    public bool SupportsAutomaticPayout => false;

    public Task<PayoutSubmissionResult> SubmitAsync(
        PayoutInstruction instruction,
        CancellationToken cancellationToken)
    {
        // Not reachable in normal flow. If it ever is, retry later rather
        // than inventing a result.
        return Task.FromResult(PayoutSubmissionResult.TemporaryFailure(
            "The manual provider pays outside the system; an admin must record the payout."));
    }

    public Task<PayoutStatusResult> GetStatusAsync(
        string reference,
        string? providerReference,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(new PayoutStatusResult(PayoutState.Unknown));
    }

    public Task<PayoutWebhookEvent?> ParseWebhookAsync(
        PayoutWebhookRequest request,
        CancellationToken cancellationToken)
    {
        // No vendor, so no genuine webhook can exist.
        return Task.FromResult<PayoutWebhookEvent?>(null);
    }
}
