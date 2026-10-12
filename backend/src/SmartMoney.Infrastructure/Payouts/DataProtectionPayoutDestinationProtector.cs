using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using SmartMoney.Application.Abstractions.Payouts;

namespace SmartMoney.Infrastructure.Payouts;

/// <summary>
/// Encrypts payout destinations with ASP.NET Data Protection. The key ring
/// must survive redeploys (Payouts needs DataProtection:KeysPath outside
/// Development); a lost key ring makes stored destinations unreadable.
/// </summary>
public sealed class DataProtectionPayoutDestinationProtector
    : IPayoutDestinationProtector
{
    // Changing this string makes every stored destination unreadable.
    private const string Purpose = "SmartMoney.Payouts.Destination.v1";

    private readonly IDataProtector _protector;

    public DataProtectionPayoutDestinationProtector(
        IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector(Purpose);
    }

    public string Protect(PayoutDestination destination)
    {
        ArgumentNullException.ThrowIfNull(destination);

        return _protector.Protect(JsonSerializer.Serialize(destination));
    }

    public PayoutDestination Unprotect(string protectedValue)
    {
        if (string.IsNullOrWhiteSpace(protectedValue))
        {
            throw new ArgumentException("Nothing to decrypt.");
        }

        string json = _protector.Unprotect(protectedValue);

        return JsonSerializer.Deserialize<PayoutDestination>(json)
            ?? throw new InvalidOperationException(
                "The stored payout destination could not be read.");
    }
}
