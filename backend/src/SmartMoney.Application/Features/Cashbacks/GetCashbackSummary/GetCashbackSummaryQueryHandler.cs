using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Cashbacks;
using SmartMoney.Application.Features.Cashbacks.ListCashbacks;

namespace SmartMoney.Application.Features.Cashbacks.GetCashbackSummary;

/// <summary>Counts per queue, the overdue count and the money the network owes us.</summary>
public sealed class GetCashbackSummaryQueryHandler
    : IQueryHandler<GetCashbackSummaryQuery, AdminCashbackSummaryResponse>
{
    private readonly ICashbackRepository _cashbackRepository;

    public GetCashbackSummaryQueryHandler(ICashbackRepository cashbackRepository)
    {
        _cashbackRepository = cashbackRepository;
    }

    public async Task<AdminCashbackSummaryResponse> HandleAsync(
        GetCashbackSummaryQuery query,
        CancellationToken cancellationToken)
    {
        // One DbContext, so these run one after another.
        int ready = await CountAsync(CashbackQueue.ReadyToApprove, cancellationToken);
        int reversals = await CountAsync(CashbackQueue.ReversalsToDecide, cancellationToken);
        int rejected = await CountAsync(CashbackQueue.NetworkRejected, cancellationToken);
        int waiting = await CountAsync(CashbackQueue.WaitingOnNetwork, cancellationToken);
        int history = await CountAsync(CashbackQueue.History, cancellationToken);

        int overdue = await _cashbackRepository.CountAsync(
            new CashbackListFilter { OverdueOnly = true }, cancellationToken);

        decimal exposure = await _cashbackRepository.SumAmountAsync(
            CashbackQueues.ConfirmedNotPaidByNetwork, cancellationToken);

        return new AdminCashbackSummaryResponse
        {
            ReadyToApprove = ready,
            ReversalsToDecide = reversals,
            NetworkRejected = rejected,
            WaitingOnNetwork = waiting,
            History = history,
            NeedsDecision = ready + reversals + rejected,
            Overdue = overdue,
            ExposureAmount = exposure
        };
    }

    private Task<int> CountAsync(CashbackQueue queue, CancellationToken cancellationToken)
    {
        return _cashbackRepository.CountAsync(
            new CashbackListFilter { Queue = queue }, cancellationToken);
    }
}
