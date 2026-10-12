using System.Buffers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Features.Withdrawals.ProcessPayoutWebhook;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// Payout-provider callbacks. Anonymous because providers cannot hold a user
/// JWT; the active provider verifies each request's signature itself, and a
/// request that fails it is refused.
///
/// Answers: 200 when applied or already applied (or genuine but not ours);
/// 400 for a bad signature or body; 404 for a provider that is not the active
/// one; 413 for a body over 64 KB; 503 on a temporary failure so the provider
/// retries. The provider is given the exact request bytes to verify.
/// </summary>
[ApiController]
public sealed class PayoutWebhooksController : ControllerBase
{
    // Real callbacks are tiny; refuse anything large before buffering it.
    private const int MaxBodyBytes = 64 * 1024;

    private readonly ICommandHandler<ProcessPayoutWebhookCommand, PayoutWebhookResult> _handler;
    private readonly ILogger<PayoutWebhooksController> _logger;

    public PayoutWebhooksController(
        ICommandHandler<ProcessPayoutWebhookCommand, PayoutWebhookResult> handler,
        ILogger<PayoutWebhooksController> logger)
    {
        _handler = handler;
        _logger = logger;
    }

    [AllowAnonymous]
    [HttpPost("api/webhooks/payouts/{provider}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status413PayloadTooLarge)]
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Receive(
        string provider,
        CancellationToken cancellationToken)
    {
        if (Request.ContentLength > MaxBodyBytes)
        {
            return StatusCode(
                StatusCodes.Status413PayloadTooLarge,
                new { message = "Request body is too large." });
        }

        byte[]? body = await ReadBodyAsync(cancellationToken);

        if (body is null)
        {
            return StatusCode(
                StatusCodes.Status413PayloadTooLarge,
                new { message = "Request body is too large." });
        }

        // First value of each header, case-insensitive: signature schemes
        // differ in which headers they read.
        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (var header in Request.Headers)
        {
            headers[header.Key] = header.Value.ToString();
        }

        PayoutWebhookResult result;

        try
        {
            result = await _handler.HandleAsync(
                new ProcessPayoutWebhookCommand(provider, headers, body),
                cancellationToken);
        }
        catch (Exception exception)
        {
            // Fail loudly so the provider RETRIES: answering 200 would drop a
            // payout result on a transient failure, such as losing a race with
            // an admin action on the same withdrawal. Settlement is
            // idempotent, so a retry is safe.
            _logger.LogError(exception, "Payout webhook processing failed.");

            return StatusCode(
                StatusCodes.Status503ServiceUnavailable,
                new { message = "Temporarily unable to process; please retry." });
        }

        switch (result)
        {
            case PayoutWebhookResult.UnknownProvider:
                return NotFound(new { message = "Unknown payout provider." });

            case PayoutWebhookResult.Invalid:
                return BadRequest(new { message = "Invalid webhook." });

            case PayoutWebhookResult.NeedsAttention:
                _logger.LogWarning(
                    "Payout webhook contradicted our records; withdrawal flagged for review.");
                return Ok(new { received = true, outcome = result.ToString() });

            default:
                return Ok(new { received = true, outcome = result.ToString() });
        }
    }

    /// <summary>
    /// The exact request bytes (providers sign bytes, so nothing is decoded
    /// or re-encoded here), or null when the body exceeds the limit. Reads
    /// into a pooled buffer, one byte past the limit so oversize is
    /// detectable without pulling a huge body into memory.
    /// </summary>
    private async Task<byte[]?> ReadBodyAsync(CancellationToken cancellationToken)
    {
        byte[] buffer = ArrayPool<byte>.Shared.Rent(MaxBodyBytes + 1);

        try
        {
            int total = 0;
            int limit = MaxBodyBytes + 1;

            while (total < limit)
            {
                int read = await Request.Body.ReadAsync(
                    buffer.AsMemory(total, limit - total), cancellationToken);

                if (read == 0)
                {
                    break;
                }

                total += read;
            }

            return total > MaxBodyBytes
                ? null
                : buffer.AsSpan(0, total).ToArray();
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }
    }
}
