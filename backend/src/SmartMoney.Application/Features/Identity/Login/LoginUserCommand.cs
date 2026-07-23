using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.Login;

namespace SmartMoney.Application.Features.Identity.Login;

public sealed class LoginUserCommand
    : ICommand<LoginUserResponse>
{
    public string Email { get; }

    public string Password { get; }

    public LoginUserCommand(
        string email,
        string password)
    {
        Email = email;
        Password = password;
    }
}