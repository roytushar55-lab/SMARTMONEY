using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.GetMyWithdrawals;

public sealed class GetMyWithdrawalsQuery : IQuery<WithdrawalListResponse>
{
    public Guid UserId { get; }

    public int Page { get; }

    public int PageSize { get; }

    public GetMyWithdrawalsQuery(Guid userId, int page, int pageSize)
    {
        UserId = userId;
        Page = page;
        PageSize = pageSize;
    }
}
