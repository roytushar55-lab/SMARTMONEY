using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Affiliate;
using SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// Inbound provider callbacks. Anonymous by necessity (providers cannot hold
/// a user JWT); each webhook is guarded by its own shared-secret token that
/// lives in configuration and is carried in the registered postback.
/// </summary>
[ApiController]
public sealed class WebhooksController : ControllerBase
{
    private const string CuelinksNetworkCode = "CUELINKS";

    // Accepted names per field. The first name is the one to map in the
    // Cuelinks "Global Postback" screen; the others are Cuelinks' own macro
    // names (and our older simulator's), so an unmapped default still works.
    private static readonly string[] TransactionIdKeys = ["transaction_id", "txn_id"];
    private static readonly string[] SubIdKeys = ["sub_id", "aff_sub", "subid"];
    private static readonly string[] StatusKeys = ["status"];
    private static readonly string[] SaleAmountKeys = ["sale_amount", "amount"];
    private static readonly string[] CommissionKeys = ["commission", "user_commission"];
    private static readonly string[] CurrencyKeys = ["currency"];
    private static readonly string[] TransactionDateKeys = ["transaction_date"];
    private static readonly string[] UpdatedAtKeys = ["updated_at", "transaction_timestamp"];

    // Field names that may carry the shared secret. Never persisted.
    private static readonly string[] SecretKeys = ["token", "secret"];

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

    /// <summary>
    /// Cuelinks "Transaction Update" postback (developers.cuelinks.com,
    /// Webhooks). Cuelinks sends GET (fields in the query string) or POST
    /// (form-encoded, or JSON), with parameter names chosen in the dashboard
    /// plus a constant parameter we use as the shared secret. Statuses:
    /// pending, validated, payable, rejected, paid. Delivery is retried on any
    /// non-2xx and order is not guaranteed; ingestion is idempotent on
    /// (network, transaction id).
    /// </summary>
    [AllowAnonymous]
    [HttpGet("api/webhooks/cuelinks")]
    [HttpPost("api/webhooks/cuelinks")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> CuelinksTransactionUpdate(
        [FromQuery] string? token,
        CancellationToken cancellationToken)
    {
        string rawBody;
        using (var reader = new StreamReader(Request.Body, Encoding.UTF8))
        {
            rawBody = await reader.ReadToEndAsync(cancellationToken);
        }

        // Query string first, body fields override (Cuelinks may send both).
        var fields = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var (key, value) in Request.Query)
        {
            fields[key] = value.ToString();
        }

        if (!string.IsNullOrWhiteSpace(rawBody))
        {
            if (!TryReadBody(rawBody, Request.ContentType, fields))
            {
                // Still check the secret first, so strangers learn nothing.
                if (!IsTokenValid(PresentedToken(token, fields), "Webhooks:CuelinksToken"))
                {
                    return Unauthorized();
                }

                return BadRequest(new { message = "Malformed payload." });
            }
        }

        // Prefer the X-Webhook-Token header (query strings end up in proxy and
        // access logs); otherwise the token query parameter or the constant
        // parameter configured in the Cuelinks dashboard.
        if (!IsTokenValid(PresentedToken(token, fields), "Webhooks:CuelinksToken"))
        {
            return Unauthorized();
        }

        string? transactionId = First(fields, TransactionIdKeys);
        string? status = First(fields, StatusKeys);

        if (string.IsNullOrWhiteSpace(transactionId))
        {
            return BadRequest(new { message = "transaction_id is required." });
        }

        if (string.IsNullOrWhiteSpace(status))
        {
            return BadRequest(new { message = "status is required." });
        }

        if (!TryParseAmount(First(fields, SaleAmountKeys), out decimal? saleAmount))
        {
            return BadRequest(new { message = "sale_amount is not a number." });
        }

        if (!TryParseAmount(First(fields, CommissionKeys), out decimal? commission))
        {
            return BadRequest(new { message = "commission is not a number." });
        }

        var command = new IngestAffiliateConversionCommand(
            CuelinksNetworkCode,
            transactionId,
            First(fields, SubIdKeys),
            status,
            saleAmount,
            commission,
            First(fields, CurrencyKeys),
            ParseDate(First(fields, TransactionDateKeys)),
            ParseDate(First(fields, UpdatedAtKeys)),
            StoredPayload(rawBody, fields));

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

    private string? PresentedToken(string? queryToken, Dictionary<string, string> fields) =>
        Request.Headers["X-Webhook-Token"].FirstOrDefault()
        ?? queryToken
        ?? First(fields, SecretKeys);

    /// <summary>
    /// Adds the body's fields: JSON object, or form-encoded. False when the
    /// body is neither.
    /// </summary>
    private static bool TryReadBody(
        string rawBody,
        string? contentType,
        Dictionary<string, string> fields)
    {
        string trimmed = rawBody.TrimStart();
        bool looksJson =
            trimmed.StartsWith('{') ||
            (contentType?.Contains("json", StringComparison.OrdinalIgnoreCase) ?? false);

        if (looksJson)
        {
            try
            {
                using JsonDocument document = JsonDocument.Parse(rawBody);

                if (document.RootElement.ValueKind != JsonValueKind.Object)
                {
                    return false;
                }

                foreach (JsonProperty property in document.RootElement.EnumerateObject())
                {
                    string? value = property.Value.ValueKind switch
                    {
                        JsonValueKind.String => property.Value.GetString(),
                        JsonValueKind.Number or JsonValueKind.True or JsonValueKind.False
                            => property.Value.GetRawText(),
                        _ => null,
                    };

                    if (value is not null)
                    {
                        fields[property.Name] = value;
                    }
                }

                return true;
            }
            catch (JsonException)
            {
                return false;
            }
        }

        // Form-encoded (Cuelinks' POST) is the only other shape accepted.
        if (!rawBody.Contains('='))
        {
            return false;
        }

        foreach (var (key, value) in QueryHelpers.ParseQuery(rawBody))
        {
            fields[key] = value.ToString();
        }

        return true;
    }

    private static string? First(Dictionary<string, string> fields, string[] keys)
    {
        foreach (string key in keys)
        {
            if (fields.TryGetValue(key, out string? value) && !string.IsNullOrWhiteSpace(value))
            {
                return value.Trim();
            }
        }

        return null;
    }

    private static bool TryParseAmount(string? value, out decimal? amount)
    {
        amount = null;

        if (string.IsNullOrWhiteSpace(value))
        {
            return true;
        }

        if (decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out decimal parsed))
        {
            amount = parsed;
            return true;
        }

        return false;
    }

    private static DateTime? ParseDate(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        return DateTime.TryParse(
            value,
            CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
            out DateTime parsed)
            ? parsed
            : null;
    }

    /// <summary>
    /// What is kept with the conversion for audits: the exact body when it
    /// carries no secret, otherwise every received field except the secret.
    /// </summary>
    private static string StoredPayload(string rawBody, Dictionary<string, string> fields)
    {
        bool hasSecret = SecretKeys.Any(fields.ContainsKey);

        if (!hasSecret && !string.IsNullOrWhiteSpace(rawBody))
        {
            return rawBody;
        }

        var safe = fields
            .Where(pair => !SecretKeys.Contains(pair.Key, StringComparer.OrdinalIgnoreCase))
            .ToDictionary(pair => pair.Key, pair => pair.Value);

        return JsonSerializer.Serialize(safe);
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
}
