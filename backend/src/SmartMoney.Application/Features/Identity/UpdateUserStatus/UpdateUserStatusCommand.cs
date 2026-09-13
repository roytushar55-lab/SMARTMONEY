using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.AdminUsers;

namespace SmartMoney.Application.Features.Identity.UpdateUserStatus;

public sealed class UpdateUserStatusCommand : ICommand<AdminUserStatusResponse?>
{
    public Guid TargetUserId { get; }

    public bool IsActive { get; }

    public Guid ActingUserId { get; }

    public UpdateUserStatusCommand(Guid targetUserId, bool isActive, Guid actingUserId)
    {
        TargetUserId = targetUserId;
        IsActive = isActive;
        ActingUserId = actingUserId;
    }
}
