using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawalSummary;

public sealed record GetAdminWithdrawalSummaryQuery : IQuery<AdminWithdrawalSummaryResponse>;
