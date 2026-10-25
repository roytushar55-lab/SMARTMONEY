using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SmartMoney.Infrastructure.Affiliate;

namespace SmartMoney.Application.Tests.Affiliate;

public sealed class CuelinksAffiliateNetworkClientTests
{
    private const string ApiKey = "test-key";

    private sealed class StubHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, Task<HttpResponseMessage>> _respond;

        public StubHandler(Func<HttpRequestMessage, Task<HttpResponseMessage>> respond) => _respond = respond;

        public HttpRequestMessage? Request { get; private set; }

        public string? RequestBody { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Request = request;
            RequestBody = request.Content is null ? null : await request.Content.ReadAsStringAsync(cancellationToken);
            cancellationToken.ThrowIfCancellationRequested();
            return await _respond(request);
        }
    }

    private static HttpResponseMessage Json(HttpStatusCode status, string body) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    private static (CuelinksAffiliateNetworkClient Client, StubHandler Handler) Create(
        Func<HttpRequestMessage, Task<HttpResponseMessage>> respond,
        int? channelId = null)
    {
        var handler = new StubHandler(respond);
        var options = Options.Create(new CuelinksOptions { ApiKey = ApiKey, ChannelId = channelId });
        var client = new CuelinksAffiliateNetworkClient(
            new HttpClient(handler), options, NullLogger<CuelinksAffiliateNetworkClient>.Instance);
        return (client, handler);
    }

    private const string AffiliatedResponse = """
        {
          "data": {
            "tracking_url": "https://linksredirect.com/?cid=456&subid=ref-123&source=api&url=https%3A%2F%2Fwww.myntra.com",
            "affiliated": true,
            "original_url": "https://www.myntra.com",
            "campaign": { "id": 101, "name": "Myntra" }
          }
        }
        """;

    [Fact]
    public async Task Converts_ThroughThePublisherApi_WithSubIdAndTokenAuth()
    {
        var (client, handler) = Create(_ => Task.FromResult(Json(HttpStatusCode.OK, AffiliatedResponse)), channelId: 3424);

        var tracked = await client.BuildTrackedUrlAsync("https://www.myntra.com", "ref-123");

        Assert.Equal(
            "https://linksredirect.com/?cid=456&subid=ref-123&source=api&url=https%3A%2F%2Fwww.myntra.com",
            tracked);
        Assert.NotNull(handler.Request);
        Assert.Equal(HttpMethod.Post, handler.Request!.Method);
        Assert.Equal("https://developers.cuelinks.com/pub_api/v3/links/convert", handler.Request.RequestUri!.ToString());
        Assert.Equal($"Token {ApiKey}", handler.Request.Headers.GetValues("Authorization").Single());

        using var body = JsonDocument.Parse(handler.RequestBody!);
        Assert.Equal("https://www.myntra.com", body.RootElement.GetProperty("url").GetString());
        Assert.Equal("ref-123", body.RootElement.GetProperty("subid").GetString());
        Assert.Equal(3424, body.RootElement.GetProperty("channel_id").GetInt32());
    }

    [Fact]
    public async Task OmitsChannelId_WhenNotConfigured()
    {
        var (client, handler) = Create(_ => Task.FromResult(Json(HttpStatusCode.OK, AffiliatedResponse)));

        await client.BuildTrackedUrlAsync("https://www.myntra.com", "ref-123");

        using var body = JsonDocument.Parse(handler.RequestBody!);
        Assert.False(body.RootElement.TryGetProperty("channel_id", out _));
    }

    [Fact]
    public async Task NotAffiliated_StillReturnsTheWorkingTrackingLink()
    {
        const string response = """
            { "data": { "tracking_url": "https://linksredirect.com/?cid=456&subid=ref-1&url=x", "affiliated": false, "campaign": null } }
            """;
        var (client, _) = Create(_ => Task.FromResult(Json(HttpStatusCode.OK, response)));

        var tracked = await client.BuildTrackedUrlAsync("https://shop.example", "ref-1");

        Assert.Equal("https://linksredirect.com/?cid=456&subid=ref-1&url=x", tracked);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized, """{"error":"Invalid or expired API key"}""")]
    [InlineData(HttpStatusCode.Forbidden, """{"error":"This API key lacks the 'write:links' scope"}""")]
    [InlineData((HttpStatusCode)422, """{"error":"url is required"}""")]
    [InlineData(HttpStatusCode.InternalServerError, "oops")]
    public async Task ErrorReply_ReturnsNull_SoTheCallerFallsBack(HttpStatusCode status, string body)
    {
        var (client, _) = Create(_ => Task.FromResult(Json(status, body)));

        Assert.Null(await client.BuildTrackedUrlAsync("https://www.myntra.com", "ref-123"));
    }

    [Theory]
    [InlineData("""{ "data": { "affiliated": true } }""")]
    [InlineData("""{ "data": { "tracking_url": "javascript:alert(1)" } }""")]
    [InlineData("""{ "data": null }""")]
    [InlineData("not json")]
    public async Task UnusableReply_ReturnsNull(string body)
    {
        var (client, _) = Create(_ => Task.FromResult(Json(HttpStatusCode.OK, body)));

        Assert.Null(await client.BuildTrackedUrlAsync("https://www.myntra.com", "ref-123"));
    }

    [Fact]
    public async Task NetworkFailure_ReturnsNull()
    {
        var (client, _) = Create(_ => throw new HttpRequestException("connection refused"));

        Assert.Null(await client.BuildTrackedUrlAsync("https://www.myntra.com", "ref-123"));
    }

    [Fact]
    public async Task Timeout_ReturnsNull()
    {
        var (client, _) = Create(_ => throw new TaskCanceledException("timed out"));

        Assert.Null(await client.BuildTrackedUrlAsync("https://www.myntra.com", "ref-123"));
    }

    [Fact]
    public async Task CallerCancellation_IsNotSwallowed()
    {
        var (client, _) = Create(_ => Task.FromResult(Json(HttpStatusCode.OK, AffiliatedResponse)));
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => client.BuildTrackedUrlAsync("https://www.myntra.com", "ref-123", cts.Token));
    }
}
