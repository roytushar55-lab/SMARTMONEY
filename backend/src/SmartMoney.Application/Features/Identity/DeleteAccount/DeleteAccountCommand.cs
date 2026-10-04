using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.DeleteAccount;

namespace SmartMoney.Application.Features.Identity.DeleteAccount;

public sealed class DeleteAccountCommand : ICommand<DeleteAccountResult>
{
    public Guid UserId { get; }

    public string Password { get; }

    public DeleteAccountCommand(Guid userId, string password)
    {
        UserId = userId;
        Password = password;
    }
}
