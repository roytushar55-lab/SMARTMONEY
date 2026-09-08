namespace SmartMoney.Application.Contracts.Identity.ChangeUserRole;

public sealed class AdminUserLookupResponse
{
    public Guid UserId { get; set; }

    public string Email { get; set; } = string.Empty;

    public string FullName { get; set; } = string.Empty;

    public string Role { get; set; } = string.Empty;

    public bool IsActive { get; set; }
}
