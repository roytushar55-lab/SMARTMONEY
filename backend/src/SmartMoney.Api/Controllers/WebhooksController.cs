using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Affiliate;
using SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// Inbound provider callbacks. Anonymous by necessity (providers cannot hold
/// a user JWT); each webhook is guarded by its own shared-secret token that
/// lives in User Secrets and is carried in the registered postback URL.
/// </summary>
[ApiController]
public sealed class WebhooksController : ControllerBase
{
    private const string CuelinksNetworkCode = "CUELINKS";

    private readonly ICommandHandler<IngestAffiliateConversionCommand, IngestAffiliateConversionResponse> _ingestHandler;
    private readonly IConfiguration _configuration;
    private readonly ILogger<WebhooksController> _logger;

    public WebhooksController(
        ICommandHandler<IngestAffiliateConversionCommand, IngestAffiliateConversionResponse> ingestHandler,
        IConfiguration configuration,
        ILogger<WebhooksController> logger)
    {
        _ingestHandler = ingestHandler;
        _configuration = configuration;
        _logger = logger;
    }

    // Field names follow the publicly documented Cuelinks Transaction Update
    // postback conventions (sub_id echoes our TrackingReference). VERIFY the
    // exact contract against a live Cuelinks account before production — this
    // mapping is exercised today by the local simulator, not by Cuelinks.
    [AllowAnonymous]
    [HttpPost("api/webhooks/cuelinks")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> CuelinksTransactionUpdate(
        [FromQuery] string? token,
        CancellationToken cancellationToken)
    {
        // Prefer the X-Webhook-Token header (query strings end up in proxy and
        // access logs); the query parameter stays for providers that can only
        // configure a URL.
        string? presentedToken =
            Request.Headers["X-Webhook-Token"].FirstOrDefault() ?? token;

        if (!IsTokenValid(presentedToken, "Webhooks:CuelinksToken"))
        {
            return Unauthorized();
        }

        // The exact raw body is persisted with the conversion, so read it
        // verbatim and parse from the same string.
        string rawBody;
        using (var reader = new StreamReader(Request.Body, Encoding.UTF8))
        {
            rawBody = await reader.ReadToEndAsync(cancellationToken);
        }

        CuelinksPostbackPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<CuelinksPostbackPayload>(rawBody);
        }
        catch (JsonException)
        {
            return BadRequest(new { message = "Malformed JSON payload." });
        }

        if (payload is null || string.IsNullOrWhiteSpace(payload.TransactionId))
        {
            return BadRequest(new { message = "transaction_id is required." });
        }

        if (string.IsNullOrWhiteSpace(payload.Status))
        {
            return BadRequest(new { message = "status is required." });
        }

        var command = new IngestAffiliateConversionCommand(
            CuelinksNetworkCode,
            payload.TransactionId,
            payload.SubId,
            payload.Status,
            payload.SaleAmount,
            payload.Commission,
            payload.Currency,
            payload.TransactionDate,
            payload.UpdatedAt,
            rawBody);

        try
        {
            var response = await _ingestHandler.HandleAsync(command, cancellationToken);

            return Ok(new { received = true, outcome = response.Outcome });
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
        catch (Exception exception)
        {
            // Fail loudly so the provider RETRIES. Answering 200 here would
            // silently drop the conversion (and the user's cashback) on any
            // transient failure - a DB blip, or losing a concurrency race with
            // an admin action on the same wallet. Ingestion is idempotent on
            // (network, transaction id), so a retry is safe.
            _logger.LogError(exception, "Cuelinks postback processing failed.");

            return StatusCode(
                StatusCodes.Status503ServiceUnavailable,
                new { message = "Temporarily unable to process; please retry." });
        }
    }

    private bool IsTokenValid(string? presented, string secretKeyName)
    {
        var expected = _configuration[secretKeyName];

        // An unconfigured secret disables the webhook rather than opening it.
        if (string.IsNullOrWhiteSpace(expected) || string.IsNullOrWhiteSpace(presented))
        {
            return false;
        }

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(presented),
            Encoding.UTF8.GetBytes(expected));
    }

    /// <summary>
    /// Cuelinks-shaped transaction update. Nullable throughout: postbacks are
    /// external input and validation happens in the ingestion pipeline.
    /// </summary>
    public sealed record CuelinksPostbackPayload
    {
        [JsonPropertyName("transaction_id")]
        public string? TransactionId { get; init; }

        [JsonPropertyName("campaign_id")]
        public string? CampaignId { get; init; }

        [JsonPropertyName("sub_id")]
        public string? SubId { get; init; }

        [JsonPropertyName("status")]
        public string? Status { get; init; }

        [JsonPropertyName("sale_amount")]
        public decimal? SaleAmount { get; init; }

        [JsonPropertyName("commission")]
        public decimal? Commission { get; init; }

        [JsonPropertyName("currency")]
        public string? Currency { get; init; }

        [JsonPropertyName("transaction_date")]
        public DateTime? TransactionDate { get; init; }

        [JsonPropertyName("updated_at")]
        public DateTime? UpdatedAt { get; init; }
    }
}
