using System.Text;
using SmartMoney.Application.Abstractions.Messaging;

namespace SmartMoney.Application.Features.Withdrawals.ProcessPayoutWebhook;

public enum PayoutWebhookResult
{
    /// <summary>The report changed the withdrawal.</summary>
    Applied,

    /// <summary>The same news had already been applied.</summary>
    Duplicate,

    /// <summary>Genuine, but nothing to do (still pending, or not a payout we track).</summary>
    Ignored,

    /// <summary>The report contradicts our records; an admin has been flagged.</summary>
    NeedsAttention,

    /// <summary>The signature failed or the body was not understood.</summary>
    Invalid,

    /// <summary>No such provider is active.</summary>
    UnknownProvider
}

/// <summary>A raw payout-provider callback, exactly as received.</summary>
public sealed class ProcessPayoutWebhookCommand : ICommand<PayoutWebhookResult>
{
    public string ProviderName { get; }

    public IReadOnlyDictionary<string, string> Headers { get; }

    /// <summary>The exact bytes of the request body.</summary>
    public ReadOnlyMemory<byte> Body { get; }

    public ProcessPayoutWebhookCommand(
        string providerName,
        IReadOnlyDictionary<string, string> headers,
        ReadOnlyMemory<byte> body)
    {
        ProviderName = providerName;
        Headers = headers;
        Body = body;
    }

    /// <summary>For callers that already have text (for example tests).</summary>
    public ProcessPayoutWebhookCommand(
        string providerName,
        IReadOnlyDictionary<string, string> headers,
        string body)
        : this(providerName, headers, Encoding.UTF8.GetBytes(body ?? string.Empty))
    {
    }
}
