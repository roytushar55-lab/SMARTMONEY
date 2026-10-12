using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Cashbacks;

namespace SmartMoney.Application.Features.Cashbacks.GetCashbackEvents;

public sealed record GetCashbackEventsQuery(Guid CashbackId)
    : IQuery<IReadOnlyList<CashbackEventResponse>?>;
