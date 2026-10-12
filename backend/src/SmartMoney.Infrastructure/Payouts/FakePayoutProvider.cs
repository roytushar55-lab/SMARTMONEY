using System.Text.Json;
using Microsoft.Extensions.Options;
using SmartMoney.Application.Abstractions.Payouts;

namespace SmartMoney.Infrastructure.Payouts;

/// <summary>
/// Development-only provider that lets the whole automatic flow (submit,
/// webhook, reconcile, retry) be exercised without a vendor. Choose the
/// behaviour with Payouts:Fake:Behavior. Its webhook has NO signature check,
/// which is why startup refuses this provider outside Development.
/// </summary>
public sealed class FakePayoutProvider : IPayoutProvider
{
    public const string ProviderName = "Fake";

    private readonly FakePayoutOptions _options;

    public FakePayoutProvider(IOptions<FakePayoutOptions> options)
    {
        _options = options.Value;
    }

    public string Name => ProviderName;

    public bool SupportsAutomaticPayout => true;

    public Task<PayoutSubmissionResult> SubmitAsync(
        PayoutInstruction instruction,
        CancellationToken cancellationToken)
    {
        string providerReference = "FAKE-" + instruction.Reference;

        PayoutSubmissionResult result = _options.Behavior switch
        {
            FakePayoutBehavior.Success =>
                PayoutSubmissionResult.Completed(providerReference, 0m),
            FakePayoutBehavior.Reject =>
                PayoutSubmissionResult.Rejected("Fake provider: payout rejected."),
            FakePayoutBehavior.TemporaryFailure =>
                PayoutSubmissionResult.TemporaryFailure("Fake provider: temporary outage."),
            _ => PayoutSubmissionResult.Accepted(providerReference)
        };

        return Task.FromResult(result);
    }

    public Task<PayoutStatusResult> GetStatusAsync(
        string reference,
        string? providerReference,
        CancellationToken cancellationToken)
    {
        // A pending fake payout settles the first time it is asked about.
        return Task.FromResult(new PayoutStatusResult(
            PayoutState.Succeeded,
            providerReference ?? "FAKE-" + reference,
            ActualFee: 0m));
    }

    /// <summary>
    /// Body: {"reference":"WD...","state":"Succeeded|Failed|Pending","message":"..."}.
    /// </summary>
    public Task<PayoutWebhookEvent?> ParseWebhookAsync(
        PayoutWebhookRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            using JsonDocument document = JsonDocument.Parse(request.Body);
            JsonElement root = document.RootElement;

            string? reference = root.TryGetProperty("reference", out JsonElement r)
                ? r.GetString()
                : null;

            if (string.IsNullOrWhiteSpace(reference) ||
                !root.TryGetProperty("state", out JsonElement s) ||
                !Enum.TryParse(s.GetString(), true, out PayoutState state))
            {
                return Task.FromResult<PayoutWebhookEvent?>(null);
            }

            string? message = root.TryGetProperty("message", out JsonElement m)
                ? m.GetString()
                : null;

            return Task.FromResult<PayoutWebhookEvent?>(new PayoutWebhookEvent(
                reference, "FAKE-" + reference, state, message, 0m));
        }
        catch (Exception exception) when (exception is JsonException or InvalidOperationException)
        {
            return Task.FromResult<PayoutWebhookEvent?>(null);
        }
    }
}

public enum FakePayoutBehavior
{
    /// <summary>Submit answers "completed" immediately.</summary>
    Success,

    /// <summary>Submit answers "accepted"; completion comes via webhook or reconcile.</summary>
    Pending,

    /// <summary>Submit answers with a permanent refusal.</summary>
    Reject,

    /// <summary>Submit answers with a temporary failure (exercises retries).</summary>
    TemporaryFailure
}

public sealed class FakePayoutOptions
{
    public const string SectionName = "Payouts:Fake";

    public FakePayoutBehavior Behavior { get; set; } = FakePayoutBehavior.Success;
}
