namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

public sealed class AdminUserListItemResponse
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
}
