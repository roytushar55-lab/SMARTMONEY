using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Cashbacks;

namespace SmartMoney.Application.Features.Cashbacks.ListCashbacks;

/// <summary>
/// Admin review listing. The network's reported status (the reason a cashback
/// sits in AwaitingAdminReview) is surfaced from the linked conversion.
/// </summary>
public sealed class ListCashbacksQueryHandler
    : IQueryHandler<ListCashbacksQuery, AdminCashbackListResponse>
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 100;

    private readonly ICashbackRepository _cashbackRepository;

    public ListCashbacksQueryHandler(ICashbackRepository cashbackRepository)
    {
        _cashbackRepository = cashbackRepository;
    }

    public async Task<AdminCashbackListResponse> HandleAsync(
        ListCashbacksQuery query,
        CancellationToken cancellationToken)
    {
        int page = Math.Max(query.Page, 1);
        int pageSize = query.PageSize <= 0
            ? DefaultPageSize
            : Math.Min(query.PageSize, MaxPageSize);

        var cashbacks = await _cashbackRepository.ListAsync(
            query.Filter, page, pageSize, cancellationToken);

        var totalCount = await _cashbackRepository.CountAsync(
            query.Filter, cancellationToken);

        var items = cashbacks
            .Select(cashback => new AdminCashbackListItemResponse
            {
                Id = cashback.Id,
                UserId = cashback.UserId,
                UserEmail = cashback.User.Email,
                UserFullName = cashback.User.FullName,
                StoreName = cashback.AffiliateConversion.AffiliateClick?.Store?.Name,
                CashbackAmount = cashback.CashbackAmount,
                Status = cashback.Status.ToString(),
                Queue = CashbackQueues.Classify(cashback).ToString(),
                IsOverdue = CashbackQueues.IsOverdue(cashback, query.Filter.NowUtc),
                NetworkStatus = cashback.AffiliateConversion.NetworkStatus,
                OrderAmount = cashback.AffiliateConversion.OrderAmount,
                CommissionAmount = cashback.AffiliateConversion.CommissionAmount,
                Currency = cashback.AffiliateConversion.Currency,
                CreatedAt = cashback.CreatedAt,
                ExpectedConfirmationDate = cashback.ExpectedConfirmationDate,
                ConfirmedDate = cashback.ConfirmedDate
            })
            .ToList();

        return new AdminCashbackListResponse
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }
}
