using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.AdminUsers;

namespace SmartMoney.Application.Features.Identity.GetUserStats;

public sealed class GetUserStatsQuery : IQuery<AdminUserStatsResponse>;
