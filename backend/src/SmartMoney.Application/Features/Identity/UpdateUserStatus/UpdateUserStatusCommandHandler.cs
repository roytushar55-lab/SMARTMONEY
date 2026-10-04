using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.AdminUsers;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Identity.UpdateUserStatus;

/// <summary>
/// SuperAdmin action: activate or deactivate a user. Mirrors the
/// self-protection guard in ChangeUserRoleCommandHandler — an admin cannot
/// deactivate their own account. Null response = target user not found.
/// </summary>
public sealed class UpdateUserStatusCommandHandler
    : ICommandHandler<UpdateUserStatusCommand, AdminUserStatusResponse?>
{
    private readonly IUserRepository _userRepository;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateUserStatusCommandHandler(
        IUserRepository userRepository,
        IUnitOfWork unitOfWork)
    {
        _userRepository = userRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<AdminUserStatusResponse?> HandleAsync(
        UpdateUserStatusCommand command,
        CancellationToken cancellationToken)
    {
        if (!command.IsActive && command.TargetUserId == command.ActingUserId)
        {
            throw new InvalidOperationException("You cannot deactivate your own account.");
        }

        var user = await _userRepository.GetByIdAsync(
            command.TargetUserId, cancellationToken);

        if (user is null)
        {
            return null;
        }

        if (user.Status == UserStatus.Deleted)
        {
            throw new InvalidOperationException(
                "This account was deleted by the user and cannot be activated or deactivated.");
        }

        if (command.IsActive)
        {
            user.Activate();
        }
        else
        {
            user.Deactivate();
        }

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new AdminUserStatusResponse
        {
            UserId = user.Id,
            Email = user.Email,
            IsActive = user.IsActive
        };
    }
}
