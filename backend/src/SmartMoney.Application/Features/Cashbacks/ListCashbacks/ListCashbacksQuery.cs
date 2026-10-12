using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Cashbacks;

namespace SmartMoney.Application.Features.Cashbacks.ListCashbacks;

public sealed class ListCashbacksQuery : IQuery<AdminCashbackListResponse>
{
    public CashbackListFilter Filter { get; }

    public int Page { get; }

    public int PageSize { get; }

    public ListCashbacksQuery(CashbackListFilter filter, int page, int pageSize)
    {
        Filter = filter;
        Page = page;
        PageSize = pageSize;
    }
}
