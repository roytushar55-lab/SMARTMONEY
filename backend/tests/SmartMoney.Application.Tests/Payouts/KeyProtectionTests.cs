using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Moq;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.DependencyInjection;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.DependencyInjection;

namespace SmartMoney.Application.Tests.Payouts;

/// <summary>
/// The Data Protection key ring holds the keys that encrypt bank details. On
/// disk it must be encrypted too, or reading the folder (or a backup) would
/// reveal every open withdrawal's destination.
/// </summary>
public sealed class KeyProtectionTests : IDisposable
{
    private static readonly PayoutDestination Bank = new(
        PayoutMethod.BankTransfer, "Asha Rao", null, "123456789012", "HDFC0001234");

    private readonly string _folder = Path.Combine(
        Path.GetTempPath(), "smartmoney-keys-" + Guid.NewGuid().ToString("N"));

    public KeyProtectionTests() => Directory.CreateDirectory(_folder);

    public void Dispose()
    {
        try { Directory.Delete(_folder, recursive: true); }
        catch (IOException) { /* best effort */ }
    }

    private string CreateCertificate(string password)
    {
        using var rsa = RSA.Create(2048);
        var request = new CertificateRequest(
            "CN=smartmoney-test", rsa, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        using X509Certificate2 certificate = request.CreateSelfSigned(
            DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(30));

        string path = Path.Combine(_folder, "keys.pfx");
        File.WriteAllBytes(path, certificate.Export(X509ContentType.Pfx, password));
        return path;
    }

    private ServiceProvider Build(Dictionary<string, string?> extra)
    {
        var settings = new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] =
                "Host=localhost;Database=wiring;Username=x;Password=x",
            ["Jwt:Issuer"] = "test",
            ["Jwt:Audience"] = "test",
            ["Jwt:SecretKey"] = new string('k', 48),
            ["DataProtection:KeysPath"] = Path.Combine(_folder, "ring")
        };

        foreach (var pair in extra)
        {
            settings[pair.Key] = pair.Value;
        }

        var configuration = new ConfigurationBuilder().AddInMemoryCollection(settings).Build();
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

    private string ReadKeyFiles() => string.Concat(
        Directory.GetFiles(Path.Combine(_folder, "ring"), "*.xml").Select(File.ReadAllText));

    [Fact]
    public void With_a_certificate_the_key_files_are_encrypted_and_still_readable_after_a_restart()
    {
        string pfx = CreateCertificate("pw");
        var settings = new Dictionary<string, string?>
        {
            ["DataProtection:CertificatePath"] = pfx,
            ["DataProtection:CertificatePassword"] = "pw"
        };

        string stored;
        using (var first = Build(settings))
        {
            stored = first.GetRequiredService<IPayoutDestinationProtector>().Protect(Bank);
        }

        string onDisk = ReadKeyFiles();
        Assert.Contains("EncryptedData", onDisk);
        Assert.DoesNotContain("<masterKey", onDisk);

        // A new container (a restart) reads the encrypted ring and decrypts the data.
        using var second = Build(settings);
        Assert.Equal(
            Bank,
            second.GetRequiredService<IPayoutDestinationProtector>().Unprotect(stored));
    }

    [Fact]
    public void Without_protection_the_key_files_are_plain_xml_which_is_why_it_is_required()
    {
        using (var provider = Build(new Dictionary<string, string?>()))
        {
            provider.GetRequiredService<IPayoutDestinationProtector>().Protect(Bank);
        }

        Assert.Contains("<masterKey", ReadKeyFiles());
    }

    [Fact]
    public void A_wrong_certificate_password_stops_startup()
    {
        string pfx = CreateCertificate("right");

        Assert.ThrowsAny<CryptographicException>(() => Build(new Dictionary<string, string?>
        {
            ["DataProtection:CertificatePath"] = pfx,
            ["DataProtection:CertificatePassword"] = "wrong"
        }));
    }

    [Fact]
    public void A_missing_certificate_file_stops_startup()
    {
        Assert.ThrowsAny<Exception>(() => Build(new Dictionary<string, string?>
        {
            ["DataProtection:CertificatePath"] = Path.Combine(_folder, "nope.pfx")
        }));
    }
}
