namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

public sealed class AdminUserListResponse
{
    public IReadOnlyList<AdminUserListItemResponse> Items { get; set; } =
        Array.Empty<AdminUserListItemResponse>();

    public int TotalCount { get; set; }

    public int Page { get; set; }

    public int PageSize { get; set; }
}
