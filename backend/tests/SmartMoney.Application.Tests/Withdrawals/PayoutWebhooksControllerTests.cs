using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SmartMoney.Api.Controllers;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Features.Withdrawals.ProcessPayoutWebhook;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class PayoutWebhooksControllerTests
{
    private const int Limit = 64 * 1024;

    private readonly Mock<ICommandHandler<ProcessPayoutWebhookCommand, PayoutWebhookResult>> _handler = new();
    private ProcessPayoutWebhookCommand? _seen;

    public PayoutWebhooksControllerTests()
    {
        _handler.Setup(h => h.HandleAsync(
                It.IsAny<ProcessPayoutWebhookCommand>(), It.IsAny<CancellationToken>()))
            .Callback<ProcessPayoutWebhookCommand, CancellationToken>((c, _) => _seen = c)
            .ReturnsAsync(PayoutWebhookResult.Applied);
    }

    private PayoutWebhooksController Controller(byte[] body, long? contentLength)
    {
        var context = new DefaultHttpContext();
        context.Request.Body = new MemoryStream(body);
        context.Request.ContentLength = contentLength;
        context.Request.Headers["X-Signature"] = "abc";

        return new PayoutWebhooksController(
            _handler.Object, NullLogger<PayoutWebhooksController>.Instance)
        {
            ControllerContext = new ControllerContext { HttpContext = context }
        };
    }

    private static int? Status(IActionResult result) =>
        (result as ObjectResult)?.StatusCode;

    [Fact]
    public async Task Passes_the_exact_bytes_and_headers_to_the_handler()
    {
        byte[] raw = { 0xEF, 0xBB, 0xBF, (byte)'{', 0xFF, (byte)'}' };

        var result = await Controller(raw, raw.Length).Receive("Test", default);

        Assert.Equal(StatusCodes.Status200OK, Status(result));
        Assert.Equal(raw, _seen!.Body.ToArray());
        Assert.Equal("Test", _seen.ProviderName);
        Assert.Equal("abc", _seen.Headers["x-signature"]);
    }

    [Fact]
    public async Task A_body_exactly_at_the_limit_is_accepted()
    {
        byte[] body = new byte[Limit];

        var result = await Controller(body, Limit).Receive("Test", default);

        Assert.Equal(StatusCodes.Status200OK, Status(result));
        Assert.Equal(Limit, _seen!.Body.Length);
    }

    [Fact]
    public async Task An_oversize_declared_length_is_refused_without_reading()
    {
        var result = await Controller(new byte[10], Limit + 1).Receive("Test", default);

        Assert.Equal(StatusCodes.Status413PayloadTooLarge, Status(result));
        _handler.Verify(h => h.HandleAsync(
            It.IsAny<ProcessPayoutWebhookCommand>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task An_oversize_body_with_no_declared_length_is_refused()
    {
        var result = await Controller(new byte[Limit + 1], contentLength: null)
            .Receive("Test", default);

        Assert.Equal(StatusCodes.Status413PayloadTooLarge, Status(result));
        _handler.Verify(h => h.HandleAsync(
            It.IsAny<ProcessPayoutWebhookCommand>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Theory]
    [InlineData(PayoutWebhookResult.Invalid, StatusCodes.Status400BadRequest)]
    [InlineData(PayoutWebhookResult.UnknownProvider, StatusCodes.Status404NotFound)]
    [InlineData(PayoutWebhookResult.Duplicate, StatusCodes.Status200OK)]
    [InlineData(PayoutWebhookResult.Ignored, StatusCodes.Status200OK)]
    [InlineData(PayoutWebhookResult.NeedsAttention, StatusCodes.Status200OK)]
    public async Task Outcomes_map_to_the_documented_status_codes(
        PayoutWebhookResult outcome, int expected)
    {
        _handler.Setup(h => h.HandleAsync(
                It.IsAny<ProcessPayoutWebhookCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(outcome);

        var result = await Controller(new byte[] { 1 }, 1).Receive("Test", default);

        Assert.Equal(expected, Status(result));
    }

    [Fact]
    public async Task A_failure_while_processing_asks_the_provider_to_retry()
    {
        _handler.Setup(h => h.HandleAsync(
                It.IsAny<ProcessPayoutWebhookCommand>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("db down"));

        var result = await Controller(new byte[] { 1 }, 1).Receive("Test", default);

        Assert.Equal(StatusCodes.Status503ServiceUnavailable, Status(result));
    }
}
