using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.ChangeUserRole;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Identity.ChangeUserRole;

/// <summary>
/// SuperAdmin action: grant or revoke the Admin role. Null response = target
/// user not found.
/// </summary>
public sealed class ChangeUserRoleCommandHandler
    : ICommandHandler<ChangeUserRoleCommand, ChangeUserRoleResponse?>
{
    private readonly IUserRepository _userRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly ChangeUserRoleValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public ChangeUserRoleCommandHandler(
        IUserRepository userRepository,
        IRoleRepository roleRepository,
        ChangeUserRoleValidator validator,
        IUnitOfWork unitOfWork)
    {
        _userRepository = userRepository;
        _roleRepository = roleRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<ChangeUserRoleResponse?> HandleAsync(
        ChangeUserRoleCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        if (command.TargetUserId == command.ActingUserId)
        {
            throw new InvalidOperationException("You cannot change your own role.");
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
                "This account was deleted by the user; its role cannot be changed.");
        }

        var roleType = ChangeUserRoleValidator.ParseRole(command.Role);

        var role = await _roleRepository.GetByNameAsync(roleType, cancellationToken);

        if (role is null)
        {
            throw new InvalidOperationException("Requested role is not seeded.");
        }

        user.ChangeRole(role.Id);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new ChangeUserRoleResponse
        {
            UserId = user.Id,
            Email = user.Email,
            Role = roleType.ToString()
        };
    }
}
