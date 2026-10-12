using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Moq;
using SmartMoney.Api.Controllers;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.DependencyInjection;
using SmartMoney.Infrastructure.DependencyInjection;
using SmartMoney.Infrastructure.Payouts;

namespace SmartMoney.Application.Tests.Withdrawals;

/// <summary>
/// Builds the real container (no database connection is opened) and checks
/// that every withdrawal controller can be constructed, so a missing
/// registration fails here and not on the first request.
/// </summary>
public sealed class WithdrawalWiringTests
{
    private static ServiceProvider BuildProvider(string provider = "Manual")
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] =
                    "Host=localhost;Database=wiring;Username=x;Password=x",
                ["Jwt:Issuer"] = "test",
                ["Jwt:Audience"] = "test",
                ["Jwt:SecretKey"] = new string('k', 48),
                ["Payouts:Provider"] = provider
            })
            .Build();

        var environment = new Mock<IHostEnvironment>();
        environment.SetupGet(e => e.EnvironmentName).Returns("Development");

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton<IConfiguration>(configuration);
        services.AddSingleton(environment.Object);
        services.AddApplication();
        services.AddInfrastructure(configuration);

        return services.BuildServiceProvider();
    }

    [Theory]
    [InlineData(typeof(WithdrawalsController))]
    [InlineData(typeof(AdminWithdrawalsController))]
    [InlineData(typeof(PayoutWebhooksController))]
    public void Controllers_can_be_constructed(Type controller)
    {
        using ServiceProvider root = BuildProvider();
        using IServiceScope scope = root.CreateScope();

        object instance = ActivatorUtilities.CreateInstance(
            scope.ServiceProvider, controller);

        Assert.NotNull(instance);
    }

    [Theory]
    [InlineData("Manual", typeof(ManualPayoutProvider))]
    [InlineData("Fake", typeof(FakePayoutProvider))]
    public void The_configured_provider_is_the_active_one(string name, Type expected)
    {
        using ServiceProvider root = BuildProvider(name);

        Assert.IsType(expected, root.GetRequiredService<IPayoutProvider>());
    }
}
