namespace SmartMoney.Application.Contracts.Withdrawals;

public sealed class WithdrawalListResponse
{
    public IReadOnlyList<WithdrawalResponse> Items { get; set; } =
        Array.Empty<WithdrawalResponse>();

    public int TotalCount { get; set; }

    public int Page { get; set; }

    public int PageSize { get; set; }
}
