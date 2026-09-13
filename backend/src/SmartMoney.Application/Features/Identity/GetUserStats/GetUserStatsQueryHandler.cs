using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.AdminUsers;

namespace SmartMoney.Application.Features.Identity.GetUserStats;

/// <summary>
/// Dashboard KPI tile data: user counts by active status, plus signups in
/// the trailing 7 days as a growth signal.
/// </summary>
public sealed class GetUserStatsQueryHandler
    : IQueryHandler<GetUserStatsQuery, AdminUserStatsResponse>
{
    private readonly IUserRepository _userRepository;

    public GetUserStatsQueryHandler(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    public async Task<AdminUserStatsResponse> HandleAsync(
        GetUserStatsQuery query,
        CancellationToken cancellationToken)
    {
        var activeCount = await _userRepository.CountByActiveStatusAsync(
            true, cancellationToken);
        var deactivatedCount = await _userRepository.CountByActiveStatusAsync(
            false, cancellationToken);
        var newThisWeek = await _userRepository.CountCreatedSinceAsync(
            DateTime.UtcNow.AddDays(-7), cancellationToken);

        return new AdminUserStatsResponse
        {
            TotalUsers = activeCount + deactivatedCount,
            ActiveUsers = activeCount,
            DeactivatedUsers = deactivatedCount,
            NewThisWeek = newThisWeek
        };
    }
}
