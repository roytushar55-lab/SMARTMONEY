using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.Login;

namespace SmartMoney.Application.Features.Identity.GoogleLogin;

/// <summary>
/// Returns the same <see cref="LoginUserResponse"/> shape as a normal
/// email/password login, so the frontend's existing token-saving and
/// navigation code works unchanged regardless of which method signed the
/// user in.
/// </summary>
public sealed class LoginWithGoogleCommand : ICommand<LoginUserResponse>
{
    public string IdToken { get; }

    public LoginWithGoogleCommand(string idToken)
    {
        IdToken = idToken;
    }
}
