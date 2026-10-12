using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Moq;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Common;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Payouts;

namespace SmartMoney.Application.Tests.Payouts;

public class PayoutInfrastructureTests
{
    private static readonly PayoutDestination Bank = new(
        PayoutMethod.BankTransfer, "Asha Rao", null, "123456789012", "HDFC0001234");

    [Fact]
    public void Protector_round_trips_and_does_not_leak_the_account_number()
    {
        var protector = new DataProtectionPayoutDestinationProtector(
            new EphemeralDataProtectionProvider());

        string stored = protector.Protect(Bank);

        Assert.DoesNotContain("123456789012", stored);
        Assert.Equal(Bank, protector.Unprotect(stored));
    }

    [Fact]
    public void Protector_rejects_tampered_values()
    {
        var protector = new DataProtectionPayoutDestinationProtector(
            new EphemeralDataProtectionProvider());

        Assert.ThrowsAny<Exception>(() => protector.Unprotect("not-a-real-value"));
    }

    [Theory]
    [InlineData("Manual", "Production", true)]
    [InlineData("manual", "Production", true)]
    [InlineData("Fake", "Development", true)]
    [InlineData("Fake", "Production", false)]
    [InlineData("Nope", "Development", false)]
    public void Validator_checks_provider_name_and_environment(
        string provider, string environment, bool valid)
    {
        var result = CreateValidator(environment, keysPath: "keys")
            .Validate(null, new PayoutOptions { Provider = provider });

        Assert.Equal(valid, result.Succeeded);
    }

    [Fact]
    public void Validator_requires_a_key_ring_outside_development()
    {
        var options = new PayoutOptions();

        Assert.False(CreateValidator("Production", keysPath: null)
            .Validate(null, options).Succeeded);
        Assert.True(CreateValidator("Development", keysPath: null)
            .Validate(null, options).Succeeded);
    }

    [Fact]
    public void Validator_rejects_bad_limits()
    {
        var result = CreateValidator("Development", null).Validate(
            null, new PayoutOptions { MinimumAmount = 500, MaximumAmount = 100 });

        Assert.False(result.Succeeded);
    }

    [Theory]
    [InlineData(FakePayoutBehavior.Success, PayoutSubmissionOutcome.Completed)]
    [InlineData(FakePayoutBehavior.Pending, PayoutSubmissionOutcome.Accepted)]
    [InlineData(FakePayoutBehavior.Reject, PayoutSubmissionOutcome.Rejected)]
    [InlineData(FakePayoutBehavior.TemporaryFailure, PayoutSubmissionOutcome.TemporaryFailure)]
    public async Task Fake_provider_follows_the_configured_behaviour(
        FakePayoutBehavior behavior, PayoutSubmissionOutcome expected)
    {
        var provider = new FakePayoutProvider(Options.Create(
            new FakePayoutOptions { Behavior = behavior }));

        var result = await provider.SubmitAsync(
            new PayoutInstruction("WD1", 100m, "INR", Bank, "test"), default);

        Assert.Equal(expected, result.Outcome);
    }

    [Fact]
    public async Task Fake_provider_parses_webhook_and_ignores_garbage()
    {
        var provider = new FakePayoutProvider(Options.Create(new FakePayoutOptions()));
        var headers = new Dictionary<string, string>();

        var good = await provider.ParseWebhookAsync(
            new PayoutWebhookRequest(headers, "{\"reference\":\"WD1\",\"state\":\"Failed\"}"),
            default);
        var bad = await provider.ParseWebhookAsync(
            new PayoutWebhookRequest(headers, "not json"), default);

        Assert.Equal(PayoutState.Failed, good!.State);
        Assert.Equal("WD1", good.Reference);
        Assert.Null(bad);
    }

    [Fact]
    public async Task Manual_provider_never_pays_and_accepts_no_webhooks()
    {
        var provider = new ManualPayoutProvider();

        Assert.False(provider.SupportsAutomaticPayout);
        Assert.Null(await provider.ParseWebhookAsync(
            new PayoutWebhookRequest(new Dictionary<string, string>(), "{}"), default));
    }

    [Theory]
    [InlineData("DataProtection:CertificatePath", "keys.pfx", true)]
    [InlineData("DataProtection:UseDpapi", "true", true)]
    [InlineData("DataProtection:AllowUnencryptedKeys", "true", true)]
    [InlineData("DataProtection:UseDpapi", "false", false)]
    [InlineData("DataProtection:AllowUnencryptedKeys", "false", false)]
    [InlineData("Unrelated:Setting", "x", false)]
    public void Validator_requires_key_protection_outside_development(
        string setting, string value, bool valid)
    {
        var validator = CreateValidator(
            "Production", keysPath: "keys", protection: new() { [setting] = value });

        Assert.Equal(valid, validator.Validate(null, new PayoutOptions()).Succeeded);
    }

    [Fact]
    public void Validator_does_not_require_key_protection_in_development()
    {
        var validator = CreateValidator("Development", keysPath: null, protection: new());

        Assert.True(validator.Validate(null, new PayoutOptions()).Succeeded);
    }

    private static PayoutStartupValidator CreateValidator(
        string environment,
        string? keysPath,
        Dictionary<string, string?>? protection = null)
    {
        var host = new Mock<IHostEnvironment>();
        host.SetupGet(h => h.EnvironmentName).Returns(environment);

        // Unless a test says otherwise, keys count as protected so it can
        // focus on what it is really checking.
        var settings = protection
            ?? new Dictionary<string, string?> { ["DataProtection:UseDpapi"] = "true" };
        settings["DataProtection:KeysPath"] = keysPath;

        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(settings)
            .Build();

        return new PayoutStartupValidator(host.Object, configuration);
    }
}
