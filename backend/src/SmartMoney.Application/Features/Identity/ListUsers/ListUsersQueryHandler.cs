using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.AdminUsers;

namespace SmartMoney.Application.Features.Identity.ListUsers;

/// <summary>
/// SuperAdmin listing of all users, newest first.
/// </summary>
public sealed class ListUsersQueryHandler
    : IQueryHandler<ListUsersQuery, AdminUserListResponse>
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 100;

    private readonly IUserRepository _userRepository;

    public ListUsersQueryHandler(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    public async Task<AdminUserListResponse> HandleAsync(
        ListUsersQuery query,
        CancellationToken cancellationToken)
    {
        int page = Math.Max(query.Page, 1);
        int pageSize = query.PageSize <= 0
            ? DefaultPageSize
            : Math.Min(query.PageSize, MaxPageSize);

        var users = await _userRepository.ListAsync(
            page, pageSize, query.Search, query.IsActive, cancellationToken);
        var totalCount = await _userRepository.CountAsync(
            query.Search, query.IsActive, cancellationToken);

        var items = users
            .Select(user => new AdminUserListItemResponse
            {
                UserId = user.Id,
                FullName = user.FullName,
                Email = user.Email,
                CreatedAt = user.CreatedAt,
                Role = user.Role?.Name.ToString() ?? "Unknown",
                IsActive = user.IsActive
            })
            .ToList();

        return new AdminUserListResponse
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }
}
