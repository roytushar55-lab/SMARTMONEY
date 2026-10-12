using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawalSummary;

/// <summary>Counts per queue, the rupees waiting on an admin, and what was paid lately.</summary>
public sealed class GetAdminWithdrawalSummaryQueryHandler
    : IQueryHandler<GetAdminWithdrawalSummaryQuery, AdminWithdrawalSummaryResponse>
{
    private const int PaidWindowDays = 30;

    private readonly IWithdrawalRepository _withdrawalRepository;

    public GetAdminWithdrawalSummaryQueryHandler(IWithdrawalRepository withdrawalRepository)
    {
        _withdrawalRepository = withdrawalRepository;
    }

    public async Task<AdminWithdrawalSummaryResponse> HandleAsync(
        GetAdminWithdrawalSummaryQuery query,
        CancellationToken cancellationToken)
    {
        var toDecide = WithdrawalQueues.Matches(WithdrawalQueue.ToDecide);
        var toPay = WithdrawalQueues.Matches(WithdrawalQueue.ToPay);
        var paid = WithdrawalQueues.PaidSince(DateTime.UtcNow.AddDays(-PaidWindowDays));

        // One DbContext, so these run one after another.
        return new AdminWithdrawalSummaryResponse
        {
            ToDecide = await _withdrawalRepository.CountMatchingAsync(toDecide, cancellationToken),
            ToDecideAmount = await _withdrawalRepository.SumNetAmountAsync(toDecide, cancellationToken),
            ToPay = await _withdrawalRepository.CountMatchingAsync(toPay, cancellationToken),
            ToPayAmount = await _withdrawalRepository.SumNetAmountAsync(toPay, cancellationToken),
            InProgress = await _withdrawalRepository.CountMatchingAsync(
                WithdrawalQueues.Matches(WithdrawalQueue.InProgress), cancellationToken),
            History = await _withdrawalRepository.CountMatchingAsync(
                WithdrawalQueues.Matches(WithdrawalQueue.History), cancellationToken),
            NeedsAttention = await _withdrawalRepository.CountMatchingAsync(
                WithdrawalQueues.NeedsAttention, cancellationToken),
            PaidLast30Days = await _withdrawalRepository.CountMatchingAsync(paid, cancellationToken),
            PaidLast30DaysAmount = await _withdrawalRepository.SumNetAmountAsync(paid, cancellationToken)
        };
    }
}
