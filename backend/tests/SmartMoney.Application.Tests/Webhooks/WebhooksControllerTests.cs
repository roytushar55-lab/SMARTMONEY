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

    private WebhooksController CreateController(string body, string? configuredToken = ValidToken)
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
                HttpContext = new DefaultHttpContext
                {
                    Request = { Body = new MemoryStream(Encoding.UTF8.GetBytes(body)) },
                },
            },
        };

        return controller;
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
}
