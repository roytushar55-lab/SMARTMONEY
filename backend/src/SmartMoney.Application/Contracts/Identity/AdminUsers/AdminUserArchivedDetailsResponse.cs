namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

/// <summary>
/// The personal details a user had when they deleted their account, held in
/// a restricted archive until <see cref="PurgeAfter"/>.
/// </summary>
public sealed class AdminUserArchivedDetailsResponse
{
    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string MobileNumber { get; set; } = string.Empty;

    public DateTime DeletedAt { get; set; }

    public DateTime PurgeAfter { get; set; }
}
