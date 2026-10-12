using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;

/// <summary>Lists never include the full destination; open the detail for that.</summary>
public sealed class ListAdminWithdrawalsQueryHandler
    : IQueryHandler<ListAdminWithdrawalsQuery, AdminWithdrawalListResponse>
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 100;

    private readonly IWithdrawalRepository _withdrawalRepository;

    public ListAdminWithdrawalsQueryHandler(IWithdrawalRepository withdrawalRepository)
    {
        _withdrawalRepository = withdrawalRepository;
    }

    public async Task<AdminWithdrawalListResponse> HandleAsync(
        ListAdminWithdrawalsQuery query,
        CancellationToken cancellationToken)
    {
        int page = Math.Max(query.Page, 1);
        int pageSize = query.PageSize <= 0
            ? DefaultPageSize
            : Math.Min(query.PageSize, MaxPageSize);

        var withdrawals = await _withdrawalRepository.ListAsync(
            query.Filter, page, pageSize, cancellationToken);

        int total = await _withdrawalRepository.CountAsync(
            query.Filter, cancellationToken);

        return new AdminWithdrawalListResponse
        {
            Items = withdrawals.Select(AdminWithdrawalResponse.FromEntity).ToList(),
            TotalCount = total,
            Page = page,
            PageSize = pageSize
        };
    }
}
