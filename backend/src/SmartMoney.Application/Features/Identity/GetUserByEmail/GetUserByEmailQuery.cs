using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.ChangeUserRole;

namespace SmartMoney.Application.Features.Identity.GetUserByEmail;

public sealed class GetUserByEmailQuery : IQuery<AdminUserLookupResponse?>
{
    public string Email { get; }

    public GetUserByEmailQuery(string email)
    {
        Email = email;
    }
}
