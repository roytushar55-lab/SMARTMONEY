using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.GetMyWithdrawals;

public sealed class GetMyWithdrawalsQueryHandler
    : IQueryHandler<GetMyWithdrawalsQuery, WithdrawalListResponse>
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 100;

    private readonly IWithdrawalRepository _withdrawalRepository;

    public GetMyWithdrawalsQueryHandler(IWithdrawalRepository withdrawalRepository)
    {
        _withdrawalRepository = withdrawalRepository;
    }

    public async Task<WithdrawalListResponse> HandleAsync(
        GetMyWithdrawalsQuery query,
        CancellationToken cancellationToken)
    {
        int page = Math.Max(query.Page, 1);
        int pageSize = query.PageSize <= 0
            ? DefaultPageSize
            : Math.Min(query.PageSize, MaxPageSize);

        var withdrawals = await _withdrawalRepository.ListByUserIdAsync(
            query.UserId, page, pageSize, cancellationToken);

        int total = await _withdrawalRepository.CountByUserIdAsync(
            query.UserId, cancellationToken);

        return new WithdrawalListResponse
        {
            Items = withdrawals.Select(WithdrawalResponse.FromEntity).ToList(),
            TotalCount = total,
            Page = page,
            PageSize = pageSize
        };
    }
}
