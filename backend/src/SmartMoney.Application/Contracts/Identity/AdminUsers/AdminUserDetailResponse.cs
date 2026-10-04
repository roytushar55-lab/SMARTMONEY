namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

public sealed class AdminUserDetailResponse
{
    public Guid UserId { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public string Role { get; set; } = string.Empty;

    public bool IsActive { get; set; }

    /// <summary>
    /// The user deleted their own account. Their personal details are
    /// anonymized; <see cref="IsActive"/> is false but this is distinct from
    /// an admin deactivation.
    /// </summary>
    public bool IsDeleted { get; set; }

    public AdminUserCashbackSummaryResponse CashbackSummary { get; set; } = new();

    public decimal LifetimeWithdrawn { get; set; }

    /// <summary>
    /// Original details of a self-deleted user, until the archive is purged.
    /// Null for live users and once the retention period has passed.
    /// </summary>
    public AdminUserArchivedDetailsResponse? ArchivedDetails { get; set; }
}
