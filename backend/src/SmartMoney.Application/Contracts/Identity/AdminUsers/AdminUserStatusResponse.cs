namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

public sealed class AdminUserStatusResponse
{
    public Guid UserId { get; set; }

    public string Email { get; set; } = string.Empty;

    public bool IsActive { get; set; }
}
