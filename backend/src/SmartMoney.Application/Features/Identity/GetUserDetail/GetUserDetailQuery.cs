using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.AdminUsers;

namespace SmartMoney.Application.Features.Identity.GetUserDetail;

public sealed class GetUserDetailQuery : IQuery<AdminUserDetailResponse?>
{
    public Guid UserId { get; }

    public GetUserDetailQuery(Guid userId)
    {
        UserId = userId;
    }
}
