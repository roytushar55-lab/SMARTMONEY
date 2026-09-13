namespace SmartMoney.Application.Contracts.Identity.AdminUsers;

public sealed class AdminUserCashbackSummaryResponse
{
    public CashbackStatusSummaryResponse Pending { get; set; } = new();

    public CashbackStatusSummaryResponse Approved { get; set; } = new();

    public CashbackStatusSummaryResponse Rejected { get; set; } = new();

    public CashbackStatusSummaryResponse Reversed { get; set; } = new();
}
