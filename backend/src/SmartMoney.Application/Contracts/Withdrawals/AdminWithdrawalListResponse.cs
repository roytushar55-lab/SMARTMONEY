namespace SmartMoney.Application.Contracts.Withdrawals;

public sealed class AdminWithdrawalListResponse
{
    public IReadOnlyList<AdminWithdrawalResponse> Items { get; set; } =
        Array.Empty<AdminWithdrawalResponse>();

    public int TotalCount { get; set; }

    public int Page { get; set; }

    public int PageSize { get; set; }
}
