using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Cashbacks;

namespace SmartMoney.Application.Features.Cashbacks.GetCashbackEvents;

/// <summary>
/// The audit trail of one cashback, oldest first. Null response = cashback
/// not found.
/// </summary>
public sealed class GetCashbackEventsQueryHandler
    : IQueryHandler<GetCashbackEventsQuery, IReadOnlyList<CashbackEventResponse>?>
{
    private readonly ICashbackRepository _cashbackRepository;
    private readonly ICashbackEventRepository _eventRepository;

    public GetCashbackEventsQueryHandler(
        ICashbackRepository cashbackRepository,
        ICashbackEventRepository eventRepository)
    {
        _cashbackRepository = cashbackRepository;
        _eventRepository = eventRepository;
    }

    public async Task<IReadOnlyList<CashbackEventResponse>?> HandleAsync(
        GetCashbackEventsQuery query,
        CancellationToken cancellationToken)
    {
        var cashback = await _cashbackRepository.GetByIdAsync(
            query.CashbackId, cancellationToken);

        if (cashback is null)
        {
            return null;
        }

        var events = await _eventRepository.ListByCashbackIdAsync(
            query.CashbackId, cancellationToken);

        return events
            .Select(e => new CashbackEventResponse
            {
                Id = e.Id,
                Type = e.Type.ToString(),
                ActorUserId = e.ActorUserId,
                ActorName = e.Actor?.FullName,
                ActorEmail = e.Actor?.Email,
                FromStatus = e.FromStatus?.ToString(),
                ToStatus = e.ToStatus.ToString(),
                Amount = e.Amount,
                NetworkStatus = e.NetworkStatus,
                Reason = e.Reason,
                CreatedAt = e.CreatedAt
            })
            .ToList();
    }
}
