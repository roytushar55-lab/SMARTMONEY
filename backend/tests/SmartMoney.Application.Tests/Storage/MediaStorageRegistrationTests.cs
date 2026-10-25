using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SmartMoney.Api.Storage;

namespace SmartMoney.Application.Tests.Storage;

public sealed class MediaStorageRegistrationTests
{
    private static IConfiguration Config(params (string Key, string Value)[] values)
    {
        return new ConfigurationBuilder()
            .AddInMemoryCollection(values.ToDictionary(v => v.Key, v => (string?)v.Value))
            .Build();
    }

    private static ServiceProvider Build(IConfiguration configuration)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMediaStorage(configuration);
        return services.BuildServiceProvider();
    }

    [Fact]
    public void Default_provider_is_supabase_so_existing_setups_keep_working()
    {
        using ServiceProvider provider = Build(Config());

        Assert.IsType<SupabaseProfilePhotoStorage>(provider.GetRequiredService<IProfilePhotoStorage>());
        Assert.IsType<SupabaseCatalogueMediaStorage>(provider.GetRequiredService<ICatalogueMediaStorage>());
    }

    [Fact]
    public void Azure_blob_provider_registers_the_azure_stores()
    {
        using ServiceProvider provider = Build(Config(
            ("Storage:Provider", "AzureBlob"),
            ("AzureBlobStorage:ConnectionString", "UseDevelopmentStorage=true")));

        Assert.IsType<AzureBlobProfilePhotoStorage>(provider.GetRequiredService<IProfilePhotoStorage>());
        Assert.IsType<AzureBlobCatalogueMediaStorage>(provider.GetRequiredService<ICatalogueMediaStorage>());
    }

    [Fact]
    public void Azure_blob_provider_without_credentials_fails_at_startup()
    {
        var exception = Assert.Throws<InvalidOperationException>(
            () => Build(Config(("Storage:Provider", "AzureBlob"))));

        Assert.Contains("AzureBlobStorage:ConnectionString", exception.Message);
    }

    [Fact]
    public void Unknown_provider_fails_at_startup()
    {
        var exception = Assert.Throws<InvalidOperationException>(
            () => Build(Config(("Storage:Provider", "S3"))));

        Assert.Contains("'S3' is not known", exception.Message);
    }
}
