using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.AdminUsers;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Identity.GetUserDetail;

/// <summary>
/// SuperAdmin user detail: profile plus cashback totals by status (a single
/// grouped repository round-trip) and lifetime wallet withdrawals. Null
/// response = user not found.
/// </summary>
public sealed class GetUserDetailQueryHandler
    : IQueryHandler<GetUserDetailQuery, AdminUserDetailResponse?>
{
    private readonly IUserRepository _userRepository;
    private readonly ICashbackRepository _cashbackRepository;
    private readonly IWalletRepository _walletRepository;

    public GetUserDetailQueryHandler(
        IUserRepository userRepository,
        ICashbackRepository cashbackRepository,
        IWalletRepository walletRepository)
    {
        _userRepository = userRepository;
        _cashbackRepository = cashbackRepository;
        _walletRepository = walletRepository;
    }

    public async Task<AdminUserDetailResponse?> HandleAsync(
        GetUserDetailQuery query,
        CancellationToken cancellationToken)
    {
        var user = await _userRepository.GetByIdAsync(query.UserId, cancellationToken);

        if (user is null)
        {
            return null;
        }

        var summary = await _cashbackRepository.GetStatusSummaryByUserIdAsync(
            user.Id, cancellationToken);

        var wallet = await _walletRepository.GetByUserIdAsync(user.Id, cancellationToken);

        return new AdminUserDetailResponse
        {
            UserId = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            CreatedAt = user.CreatedAt,
            Role = user.Role?.Name.ToString() ?? "Unknown",
            IsActive = user.IsActive,
            CashbackSummary = new AdminUserCashbackSummaryResponse
            {
                Pending = ToSummary(summary, CashbackStatus.Pending),
                Approved = ToSummary(summary, CashbackStatus.Confirmed),
                Rejected = ToSummary(summary, CashbackStatus.Rejected),
                Reversed = ToSummary(summary, CashbackStatus.Reversed)
            },
            LifetimeWithdrawn = wallet?.TotalWithdrawn ?? 0
        };
    }

    private static CashbackStatusSummaryResponse ToSummary(
        IReadOnlyDictionary<CashbackStatus, (int Count, decimal Amount)> summary,
        CashbackStatus status)
    {
        return summary.TryGetValue(status, out var value)
            ? new CashbackStatusSummaryResponse { Count = value.Count, Amount = value.Amount }
            : new CashbackStatusSummaryResponse();
    }
}
