using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Identity.DeleteAccount;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Identity.DeleteAccount;

/// <summary>
/// User-initiated account deletion. Requires the current password, refuses
/// while the wallet holds confirmed money (it must be withdrawn first),
/// forfeits any unconfirmed cashback, then anonymizes the user's personal
/// data (keeping a 90-day restricted archive copy) and revokes every
/// session. Wallet and ledger rows are kept for the
/// retention period stated in the Privacy Policy.
/// </summary>
public sealed class DeleteAccountCommandHandler
    : ICommandHandler<DeleteAccountCommand, DeleteAccountResult>
{
    /// <summary>
    /// How long the original name/email/phone stay in the SuperAdmin-only
    /// archive. Placeholder pending the lawyer's answer to L16.
    /// </summary>
    public static readonly TimeSpan ArchiveRetention = TimeSpan.FromDays(90);

    private readonly IUserRepository _userRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly ICashbackRepository _cashbackRepository;
    private readonly IWalletTransactionRepository _walletTransactionRepository;
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IDeletedUserArchiveRepository _archiveRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IUnitOfWork _unitOfWork;

    public DeleteAccountCommandHandler(
        IUserRepository userRepository,
        IWalletRepository walletRepository,
        ICashbackRepository cashbackRepository,
        IWalletTransactionRepository walletTransactionRepository,
        IRefreshTokenRepository refreshTokenRepository,
        IDeletedUserArchiveRepository archiveRepository,
        IPasswordHasher passwordHasher,
        IUnitOfWork unitOfWork)
    {
        _userRepository = userRepository;
        _walletRepository = walletRepository;
        _cashbackRepository = cashbackRepository;
        _walletTransactionRepository = walletTransactionRepository;
        _refreshTokenRepository = refreshTokenRepository;
        _archiveRepository = archiveRepository;
        _passwordHasher = passwordHasher;
        _unitOfWork = unitOfWork;
    }

    public async Task<DeleteAccountResult> HandleAsync(
        DeleteAccountCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        if (string.IsNullOrWhiteSpace(command.Password))
        {
            throw new ArgumentException("Password is required.");
        }

        User? user = await _userRepository.GetByIdAsync(
            command.UserId,
            cancellationToken);

        if (user is null || user.Status == UserStatus.Deleted)
        {
            throw new KeyNotFoundException("Account was not found.");
        }

        if (user.PasswordHash is null ||
            !_passwordHasher.Verify(command.Password, user.PasswordHash))
        {
            throw new ArgumentException("Incorrect password.");
        }

        Wallet? wallet = await _walletRepository.GetByUserIdAsync(
            user.Id,
            cancellationToken);

        if (wallet is not null && wallet.AvailableBalance > 0)
        {
            throw new InvalidOperationException(
                "Withdraw your wallet balance before deleting your account.");
        }

        decimal forfeited = 0;

        if (wallet is not null)
        {
            IReadOnlyList<Cashback> open =
                await _cashbackRepository.ListUnconfirmedByUserIdAsync(
                    user.Id,
                    cancellationToken);

            foreach (Cashback cashback in open)
            {
                cashback.Reject();
                wallet.RemovePendingCashback(cashback.CashbackAmount);
                forfeited += cashback.CashbackAmount;

                await _walletTransactionRepository.AddAsync(
                    new WalletTransaction(
                        wallet.Id,
                        user.Id,
                        WalletTransactionType.CashbackRejected,
                        cashback.CashbackAmount,
                        cashback.Id,
                        "Cashback forfeited on account deletion.",
                        wallet.AvailableBalance,
                        wallet.PendingBalance),
                    cancellationToken);
            }
        }

        string? previousImageUrl = user.ProfileImageUrl;

        // A restricted, time-limited copy of the original details is kept
        // for fraud checks and open disputes, then purged (see
        // ArchiveRetention and the Privacy Policy, section 13).
        await _archiveRepository.AddAsync(
            new DeletedUserArchive(
                user.Id,
                user.FullName,
                user.Email,
                user.MobileNumber,
                ArchiveRetention),
            cancellationToken);

        user.AnonymizeForDeletion();

        await _refreshTokenRepository.RevokeAllForUserAsync(
            user.Id,
            cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new DeleteAccountResult(previousImageUrl, forfeited);
    }
}
