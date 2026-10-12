using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using SmartMoney.Application.Common;

namespace SmartMoney.Infrastructure.Payouts;

/// <summary>
/// Fails startup, rather than the first withdrawal, when payout settings are
/// wrong: unknown provider, Fake outside Development, nonsense limits or fees,
/// or no persistent Data Protection key ring where bank details are encrypted.
/// </summary>
public sealed class PayoutStartupValidator : IValidateOptions<PayoutOptions>
{
    private readonly IHostEnvironment _environment;
    private readonly IConfiguration _configuration;

    public PayoutStartupValidator(
        IHostEnvironment environment,
        IConfiguration configuration)
    {
        _environment = environment;
        _configuration = configuration;
    }

    public ValidateOptionsResult Validate(string? name, PayoutOptions options)
    {
        if (!PayoutProviders.Catalog.TryGetValue(
                options.Provider ?? string.Empty,
                out PayoutProviders.Entry? entry))
        {
            return ValidateOptionsResult.Fail(
                $"Payouts:Provider '{options.Provider}' is not known. " +
                $"Known providers: {PayoutProviders.KnownNames}.");
        }

        if (entry.DevelopmentOnly && !_environment.IsDevelopment())
        {
            return ValidateOptionsResult.Fail(
                $"Payouts:Provider '{options.Provider}' is allowed in Development only.");
        }

        try
        {
            // PayoutPolicy checks limits and fees in its constructor.
            _ = new PayoutPolicy(options);
        }
        catch (InvalidOperationException exception)
        {
            return ValidateOptionsResult.Fail(exception.Message);
        }

        if (!_environment.IsDevelopment() &&
            string.IsNullOrWhiteSpace(_configuration["DataProtection:KeysPath"]))
        {
            return ValidateOptionsResult.Fail(
                "DataProtection:KeysPath must be set outside Development. " +
                "Payout bank details are encrypted with these keys; without a " +
                "persistent key ring they become unreadable after a redeploy.");
        }

        if (!_environment.IsDevelopment() && !KeysAreProtected())
        {
            return ValidateOptionsResult.Fail(
                "The Data Protection keys must be encrypted at rest outside " +
                "Development, because anyone who can read the key folder or a " +
                "backup of it could decrypt stored bank details. Set " +
                "DataProtection:CertificatePath (and CertificatePassword), or " +
                "DataProtection:UseDpapi=true on Windows. To knowingly accept " +
                "unencrypted keys set DataProtection:AllowUnencryptedKeys=true.");
        }

        return ValidateOptionsResult.Success;
    }

    private bool KeysAreProtected()
    {
        return !string.IsNullOrWhiteSpace(_configuration["DataProtection:CertificatePath"])
            || _configuration.GetValue<bool>("DataProtection:UseDpapi")
            || _configuration.GetValue<bool>("DataProtection:AllowUnencryptedKeys");
    }
}
