namespace SmartMoney.Application.Contracts.Identity.GoogleLogin;

public sealed class GoogleLoginRequest
{
    /// <summary>
    /// The ID token returned by Google Sign-In on the client. Never trust an
    /// email/name supplied directly by the client instead — only what this
    /// token verifies to server-side.
    /// </summary>
    public string IdToken { get; set; } = string.Empty;
}
