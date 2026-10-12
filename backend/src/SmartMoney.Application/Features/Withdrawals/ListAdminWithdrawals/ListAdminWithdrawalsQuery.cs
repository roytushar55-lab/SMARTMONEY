using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;

public sealed class ListAdminWithdrawalsQuery : IQuery<AdminWithdrawalListResponse>
{
    public WithdrawalListFilter Filter { get; }

    public int Page { get; }

    public int PageSize { get; }

    public ListAdminWithdrawalsQuery(WithdrawalListFilter filter, int page, int pageSize)
    {
        Filter = filter;
        Page = page;
        PageSize = pageSize;
    }
}
