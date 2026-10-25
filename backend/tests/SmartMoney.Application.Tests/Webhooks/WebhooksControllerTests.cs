using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SmartMoney.Api.Controllers;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Affiliate;
using SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;

namespace SmartMoney.Application.Tests.Webhooks;

public sealed class WebhooksControllerTests
{
    private const string ValidToken = "test-webhook-token";

    private readonly Mock<ICommandHandler<IngestAffiliateConversionCommand, IngestAffiliateConversionResponse>> _handler = new();

    private WebhooksController CreateController(
        string body,
        string? configuredToken = ValidToken,
        string method = "POST",
        string? query = null,
        string? contentType = null,
        string? headerToken = null)
    {
        var configValues = new Dictionary<string, string?>();
        if (configuredToken is not null)
        {
            configValues["Webhooks:CuelinksToken"] = configuredToken;
        }

        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(configValues)
            .Build();

        var controller = new WebhooksController(
            _handler.Object, configuration, NullLogger<WebhooksController>.Instance)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = BuildContext(body, method, query, contentType, headerToken),
            },
        };

        return controller;
    }

    private static DefaultHttpContext BuildContext(
        string body, string method, string? query, string? contentType, string? headerToken)
    {
        var context = new DefaultHttpContext();
        context.Request.Method = method;
        context.Request.Body = new MemoryStream(Encoding.UTF8.GetBytes(body));
        if (query is not null)
        {
            context.Request.QueryString = new QueryString(query);
        }

        if (contentType is not null)
        {
            context.Request.ContentType = contentType;
        }

        if (headerToken is not null)
        {
            context.Request.Headers["X-Webhook-Token"] = headerToken;
        }

        return context;
    }

    private static string ValidBody(string status = "pending")
    {
        return $$"""
            {
              "transaction_id": "TXN-1",
              "sub_id": "ref-1",
              "status": "{{status}}",
              "commission": 250.00,
              "currency": "INR"
            }
            """;
    }

    private void SetupHandlerSuccess()
    {
        _handler.Setup(h => h.HandleAsync(
                It.IsAny<IngestAffiliateConversionCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new IngestAffiliateConversionResponse(
                Guid.NewGuid(), "Created", true, Guid.NewGuid()));
    }

    [Fact]
    public async Task ValidTokenAndPayload_Returns200_AndForwardsCommand()
    {
        SetupHandlerSuccess();
        IngestAffiliateConversionCommand? forwarded = null;
        _handler.Setup(h => h.HandleAsync(
                It.IsAny<IngestAffiliateConversionCommand>(), It.IsAny<CancellationToken>()))
            .Callback<IngestAffiliateConversionCommand, CancellationToken>((c, _) => forwarded = c)
            .ReturnsAsync(new IngestAffiliateConversionResponse(Guid.NewGuid(), "Created", true, null));

        var result = await CreateController(ValidBody())
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
        Assert.NotNull(forwarded);
        Assert.Equal("CUELINKS", forwarded!.NetworkCode);
        Assert.Equal("TXN-1", forwarded.NetworkTransactionId);
        Assert.Equal("ref-1", forwarded.TrackingReference);
        Assert.Equal(250.00m, forwarded.CommissionAmount);
        Assert.Contains("TXN-1", forwarded.RawPayload); // exact raw body persisted
    }

    [Fact]
    public async Task WrongToken_Returns401_WithoutTouchingHandler()
    {
        var result = await CreateController(ValidBody())
            .CuelinksTransactionUpdate("wrong-token", CancellationToken.None);

        Assert.IsType<UnauthorizedResult>(result);
        _handler.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task MissingToken_Returns401()
    {
        var result = await CreateController(ValidBody())
            .CuelinksTransactionUpdate(null, CancellationToken.None);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public async Task UnconfiguredSecret_DisablesWebhook()
    {
        var result = await CreateController(ValidBody(), configuredToken: null)
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public async Task MalformedJson_Returns400()
    {
        var result = await CreateController("{not json")
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task MissingTransactionId_Returns400()
    {
        var result = await CreateController("""{"status":"pending"}""")
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task ProcessingFailure_Returns503_SoProviderRetries()
    {
        _handler.Setup(h => h.HandleAsync(
                It.IsAny<IngestAffiliateConversionCommand>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Unknown affiliate network."));

        var result = await CreateController(ValidBody())
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        var response = Assert.IsType<ObjectResult>(result);
        Assert.Equal(503, response.StatusCode);
    }

    private void CaptureInto(Action<IngestAffiliateConversionCommand> capture)
    {
        _handler.Setup(h => h.HandleAsync(
                It.IsAny<IngestAffiliateConversionCommand>(), It.IsAny<CancellationToken>()))
            .Callback<IngestAffiliateConversionCommand, CancellationToken>((c, _) => capture(c))
            .ReturnsAsync(new IngestAffiliateConversionResponse(Guid.NewGuid(), "Created", true, null));
    }

    [Fact]
    public async Task CuelinksGetPostback_WithMappedQueryFields_IsIngested()
    {
        IngestAffiliateConversionCommand? forwarded = null;
        CaptureInto(c => forwarded = c);

        const string query =
            "?transaction_id=1234567&campaign_id=101&status=validated&sale_amount=1500.00" +
            "&commission=67.50&currency=INR&transaction_date=2026-03-20" +
            "&updated_at=2026-03-22%2014%3A00%3A00&sub_id=ref-9&token=" + ValidToken;

        var result = await CreateController("", method: "GET", query: query)
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
        Assert.NotNull(forwarded);
        Assert.Equal("1234567", forwarded!.NetworkTransactionId);
        Assert.Equal("ref-9", forwarded.TrackingReference);
        Assert.Equal("validated", forwarded.NetworkStatus);
        Assert.Equal(1500.00m, forwarded.OrderAmount);
        Assert.Equal(67.50m, forwarded.CommissionAmount);
        Assert.Equal("INR", forwarded.Currency);
        Assert.Equal(new DateTime(2026, 3, 20, 0, 0, 0, DateTimeKind.Utc), forwarded.TransactionOccurredAt);
        Assert.Equal(new DateTime(2026, 3, 22, 14, 0, 0, DateTimeKind.Utc), forwarded.NetworkUpdatedAt);
        // The shared secret is never stored with the conversion.
        Assert.DoesNotContain(ValidToken, forwarded.RawPayload);
        Assert.Contains("1234567", forwarded.RawPayload);
    }

    [Fact]
    public async Task CuelinksFormPostback_WithDefaultMacroNamesAndSecretField_IsIngested()
    {
        IngestAffiliateConversionCommand? forwarded = null;
        CaptureInto(c => forwarded = c);

        // Cuelinks' own macro names (aff_sub, user_commission, transaction_timestamp)
        // and the secret as a constant body parameter, form-encoded.
        string body =
            "transaction_id=777&status=payable&sale_amount=999.5&user_commission=45.25" +
            "&aff_sub=ref-7&transaction_timestamp=2026-03-22T14%3A00%3A00Z&secret=" + ValidToken;

        var result = await CreateController(
                body, contentType: "application/x-www-form-urlencoded")
            .CuelinksTransactionUpdate(null, CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
        Assert.NotNull(forwarded);
        Assert.Equal("777", forwarded!.NetworkTransactionId);
        Assert.Equal("ref-7", forwarded.TrackingReference);
        Assert.Equal("payable", forwarded.NetworkStatus);
        Assert.Equal(45.25m, forwarded.CommissionAmount);
        Assert.Equal(999.5m, forwarded.OrderAmount);
        Assert.Equal(new DateTime(2026, 3, 22, 14, 0, 0, DateTimeKind.Utc), forwarded.NetworkUpdatedAt);
        Assert.DoesNotContain(ValidToken, forwarded.RawPayload);
    }

    [Fact]
    public async Task HeaderToken_IsAccepted()
    {
        SetupHandlerSuccess();

        var result = await CreateController(ValidBody(), headerToken: ValidToken)
            .CuelinksTransactionUpdate(null, CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task WrongSecretInFormBody_Returns401()
    {
        var result = await CreateController(
                "transaction_id=1&status=pending&secret=nope",
                contentType: "application/x-www-form-urlencoded")
            .CuelinksTransactionUpdate(null, CancellationToken.None);

        Assert.IsType<UnauthorizedResult>(result);
        _handler.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task NonNumericCommission_Returns400()
    {
        var result = await CreateController(
                "transaction_id=1&status=pending&commission=abc",
                contentType: "application/x-www-form-urlencoded")
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
        _handler.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task MissingStatus_Returns400()
    {
        var result = await CreateController("", method: "GET", query: "?transaction_id=1")
            .CuelinksTransactionUpdate(ValidToken, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }
}
