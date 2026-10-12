namespace SmartMoney.Application.Abstractions.Payouts;

/// <summary>
/// Encrypts payout destinations (UPI IDs, bank accounts) for storage. The
/// full destination is only ever stored in this protected form, and is wiped
/// once a withdrawal finishes.
/// </summary>
public interface IPayoutDestinationProtector
{
    string Protect(PayoutDestination destination);

    /// <summary>Throws when the value cannot be decrypted (for example a lost key).</summary>
    PayoutDestination Unprotect(string protectedValue);
}
