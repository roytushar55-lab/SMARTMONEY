namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

public sealed class AdminUserDetailResponse
{
    public Guid UserId { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public string Role { get; set; } = string.Empty;

    public bool IsActive { get; set; }

    public AdminUserCashbackSummaryResponse CashbackSummary { get; set; } = new();

    public decimal LifetimeWithdrawn { get; set; }
}
