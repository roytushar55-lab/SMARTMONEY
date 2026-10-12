using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Abstractions.Payouts;

/// <summary>
/// Where a payout goes. Held only in memory (and encrypted at rest on the
/// withdrawal); never logged.
/// </summary>
public sealed record PayoutDestination(
    PayoutMethod Method,
    string BeneficiaryName,
    string? UpiId,
    string? BankAccountNumber,
    string? IfscCode)
{
    /// <summary>A form that is safe to show in lists and logs.</summary>
    public string Mask()
    {
        return Method switch
        {
            PayoutMethod.Upi => MaskUpi(UpiId),
            PayoutMethod.BankTransfer => MaskBank(BankAccountNumber, IfscCode),
            _ => "****"
        };
    }

    private static string MaskUpi(string? upiId)
    {
        if (string.IsNullOrWhiteSpace(upiId))
        {
            return "****";
        }

        int at = upiId.IndexOf('@');

        if (at <= 0)
        {
            return "****";
        }

        string handle = upiId[..at];
        string domain = upiId[at..];
        string visible = handle.Length <= 2 ? handle[..1] : handle[..2];

        return $"{visible}****{domain}";
    }

    private static string MaskBank(string? accountNumber, string? ifsc)
    {
        string account = string.IsNullOrWhiteSpace(accountNumber)
            ? "****"
            : "****" + accountNumber[^Math.Min(4, accountNumber.Length)..];

        return string.IsNullOrWhiteSpace(ifsc)
            ? account
            : $"{ifsc} {account}";
    }
}

/// <summary>Everything a provider needs to pay one withdrawal.</summary>
/// <param name="Reference">
/// Our unique id. Providers must treat it as an idempotency key: submitting
/// the same reference twice must never pay twice.
/// </param>
/// <param name="Amount">The net amount to send, in rupees.</param>
public sealed record PayoutInstruction(
    string Reference,
    decimal Amount,
    string Currency,
    PayoutDestination Destination,
    string Narration);

public enum PayoutSubmissionOutcome
{
    /// <summary>The provider accepted it; the final result will arrive later.</summary>
    Accepted,

    /// <summary>The provider already finished the payout (instant rails).</summary>
    Completed,

    /// <summary>A permanent refusal (bad account, blocked, over a limit). Do not retry.</summary>
    Rejected,

    /// <summary>A temporary problem (timeout, provider outage). Safe to retry.</summary>
    TemporaryFailure
}

public sealed record PayoutSubmissionResult(
    PayoutSubmissionOutcome Outcome,
    string? ProviderReference = null,
    string? Message = null,
    decimal? ActualFee = null)
{
    public static PayoutSubmissionResult Accepted(string? providerReference) =>
        new(PayoutSubmissionOutcome.Accepted, providerReference);

    public static PayoutSubmissionResult Completed(
        string? providerReference, decimal? actualFee = null) =>
        new(PayoutSubmissionOutcome.Completed, providerReference, null, actualFee);

    public static PayoutSubmissionResult Rejected(string message) =>
        new(PayoutSubmissionOutcome.Rejected, null, message);

    public static PayoutSubmissionResult TemporaryFailure(string message) =>
        new(PayoutSubmissionOutcome.TemporaryFailure, null, message);
}

public enum PayoutState
{
    /// <summary>Still in flight.</summary>
    Pending,

    Succeeded,

    Failed,

    /// <summary>The provider does not know this payout.</summary>
    Unknown
}

public sealed record PayoutStatusResult(
    PayoutState State,
    string? ProviderReference = null,
    string? Message = null,
    decimal? ActualFee = null);

/// <summary>
/// A raw webhook call, handed to the provider to verify and decode.
/// Verify signatures over <see cref="RawBody"/>, the exact bytes received:
/// <see cref="Body"/> is a text decoding of them, and decoding can drop a BOM
/// or replace invalid bytes, which would break a signature over the original.
/// </summary>
public sealed record PayoutWebhookRequest(
    IReadOnlyDictionary<string, string> Headers,
    ReadOnlyMemory<byte> RawBody)
{
    /// <summary>For callers that already have text (for example tests).</summary>
    public PayoutWebhookRequest(
        IReadOnlyDictionary<string, string> headers,
        string body)
        : this(headers, System.Text.Encoding.UTF8.GetBytes(body ?? string.Empty))
    {
    }

    /// <summary>The body as UTF-8 text, for parsing once the signature is verified.</summary>
    public string Body => System.Text.Encoding.UTF8.GetString(RawBody.Span);
}

/// <summary>A verified status update decoded from a webhook.</summary>
public sealed record PayoutWebhookEvent(
    string Reference,
    string? ProviderReference,
    PayoutState State,
    string? Message,
    decimal? ActualFee);
