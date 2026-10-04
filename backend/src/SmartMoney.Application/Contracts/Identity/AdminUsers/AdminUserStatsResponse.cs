namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

public sealed class AdminUserStatsResponse
{
    public int TotalUsers { get; set; }

    public int ActiveUsers { get; set; }

    public int DeactivatedUsers { get; set; }

    /// <summary>Accounts the user deleted themselves (anonymized).</summary>
    public int DeletedUsers { get; set; }

    /// <summary>Users created in the trailing 7 days, as of now.</summary>
    public int NewThisWeek { get; set; }
}
