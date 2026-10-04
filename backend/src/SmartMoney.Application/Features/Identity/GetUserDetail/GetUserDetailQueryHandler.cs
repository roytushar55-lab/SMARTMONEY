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
    private readonly IDeletedUserArchiveRepository _archiveRepository;

    public GetUserDetailQueryHandler(
        IUserRepository userRepository,
        ICashbackRepository cashbackRepository,
        IWalletRepository walletRepository,
        IDeletedUserArchiveRepository archiveRepository)
    {
        _userRepository = userRepository;
        _cashbackRepository = cashbackRepository;
        _walletRepository = walletRepository;
        _archiveRepository = archiveRepository;
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

        var archive = user.Status == UserStatus.Deleted
            ? await _archiveRepository.GetByUserIdAsync(user.Id, cancellationToken)
            : null;

        return new AdminUserDetailResponse
        {
            UserId = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            CreatedAt = user.CreatedAt,
            Role = user.Role?.Name.ToString() ?? "Unknown",
            IsActive = user.IsActive,
            IsDeleted = user.Status == UserStatus.Deleted,
            CashbackSummary = new AdminUserCashbackSummaryResponse
            {
                Pending = ToSummary(summary, CashbackStatus.Pending),
                Approved = ToSummary(summary, CashbackStatus.Confirmed),
                Rejected = ToSummary(summary, CashbackStatus.Rejected),
                Reversed = ToSummary(summary, CashbackStatus.Reversed)
            },
            LifetimeWithdrawn = wallet?.TotalWithdrawn ?? 0,
            ArchivedDetails = archive is null
                ? null
                : new AdminUserArchivedDetailsResponse
                {
                    FullName = archive.FullName,
                    Email = archive.Email,
                    MobileNumber = archive.MobileNumber,
                    DeletedAt = archive.DeletedAt,
                    PurgeAfter = archive.PurgeAfter
                }
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
