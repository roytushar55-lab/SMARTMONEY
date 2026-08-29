namespace SmartMoney.Application.Abstractions.Authentication;

public interface IGoogleIdTokenVerifier
{
    /// <summary>
    /// Verifies a Google Sign-In ID token and returns its trusted claims, or
    /// null if the token is missing, invalid, expired, issued for a
    /// different OAuth client, or belongs to an unverified email address.
    /// </summary>
    Task<GoogleIdTokenPayload?> VerifyAsync(
        string idToken,
        CancellationToken cancellationToken = default);
}
