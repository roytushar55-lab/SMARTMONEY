using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.ChangeUserRole;

namespace SmartMoney.Application.Features.Identity.GetUserByEmail;

/// <summary>
/// Lets a SuperAdmin find a user's id from their email before promoting or
/// demoting them. Null response = no user with that email.
/// </summary>
public sealed class GetUserByEmailQueryHandler
    : IQueryHandler<GetUserByEmailQuery, AdminUserLookupResponse?>
{
    private readonly IUserRepository _userRepository;

    public GetUserByEmailQueryHandler(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    public async Task<AdminUserLookupResponse?> HandleAsync(
        GetUserByEmailQuery query,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(query.Email))
        {
            return null;
        }

        var user = await _userRepository.GetByEmailAsync(
            query.Email.Trim(), cancellationToken);

        if (user is null)
        {
            return null;
        }

        return new AdminUserLookupResponse
        {
            UserId = user.Id,
            Email = user.Email,
            FullName = user.FullName,
            Role = user.Role?.Name.ToString() ?? "Unknown",
            IsActive = user.IsActive
        };
    }
}
