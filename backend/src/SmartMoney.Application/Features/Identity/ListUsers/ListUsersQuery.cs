using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.AdminUsers;

namespace SmartMoney.Application.Features.Identity.ListUsers;

public sealed class ListUsersQuery : IQuery<AdminUserListResponse>
{
    public int Page { get; }

    public int PageSize { get; }

    public string? Search { get; }

    public bool? IsActive { get; }

    public ListUsersQuery(int page, int pageSize, string? search = null, bool? isActive = null)
    {
        Page = page;
        PageSize = pageSize;
        Search = search;
        IsActive = isActive;
    }
}
