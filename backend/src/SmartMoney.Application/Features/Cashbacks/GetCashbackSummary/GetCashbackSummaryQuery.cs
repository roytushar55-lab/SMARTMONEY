using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Cashbacks;

namespace SmartMoney.Application.Features.Cashbacks.GetCashbackSummary;

public sealed record GetCashbackSummaryQuery : IQuery<AdminCashbackSummaryResponse>;
