namespace SmartMoney.Application.Abstractions.Payouts;

/// <summary>
/// The single seam between SmartMoney and a payout vendor. Everything else
/// (wallet holds, fees, approval, ledger, admin tools, webhooks) is already
/// built and vendor-neutral. To add a vendor, implement this interface and
/// register it in Infrastructure/Payouts/PayoutProviders.cs, then set
/// Payouts:Provider. See backend/docs/PAYOUT_PROVIDER_GUIDE.md.
/// </summary>
public interface IPayoutProvider
{
    /// <summary>Stable id used in configuration and in the webhook URL.</summary>
    string Name { get; }

    /// <summary>
    /// True when the provider moves money by API. False for the manual
    /// provider, where an admin pays outside the system and records it.
    /// </summary>
    bool SupportsAutomaticPayout { get; }

    /// <summary>
    /// Sends one payout. Must be idempotent on
    /// <see cref="PayoutInstruction.Reference"/>. Return a result instead of
    /// throwing for expected outcomes; an unexpected exception is treated as
    /// a temporary failure and retried.
    /// </summary>
    Task<PayoutSubmissionResult> SubmitAsync(
        PayoutInstruction instruction,
        CancellationToken cancellationToken);

    /// <summary>Asks the provider where a payout stands. Used when no webhook arrived.</summary>
    Task<PayoutStatusResult> GetStatusAsync(
        string reference,
        string? providerReference,
        CancellationToken cancellationToken);

    /// <summary>
    /// Verifies a webhook signature and decodes it. Return null when the
    /// request is not genuine or not understood; never throw for bad input.
    /// </summary>
    Task<PayoutWebhookEvent?> ParseWebhookAsync(
        PayoutWebhookRequest request,
        CancellationToken cancellationToken);
}
