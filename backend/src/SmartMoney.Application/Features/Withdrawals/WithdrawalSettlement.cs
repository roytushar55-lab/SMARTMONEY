using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals;

public enum SettlementOutcome
{
    /// <summary>The withdrawal changed state and the wallet moved.</summary>
    Applied,

    /// <summary>The same news had already been applied; nothing changed.</summary>
    Duplicate,

    /// <summary>The news contradicts our records; an admin has been flagged to look.</summary>
    NeedsAttention,

    /// <summary>Nothing to do yet (still pending, or the provider does not know it).</summary>
    Ignored
}

/// <summary>
/// The only code that moves a withdrawal into a final state. Each method
/// changes the withdrawal, moves the wallet money, and adds exactly one
/// ledger entry, in the order the ledger convention requires (wallet first).
/// It does NOT save: the caller owns the unit of work, so a settle and
/// anything else the caller does commit together or not at all.
/// </summary>
public sealed class WithdrawalSettlement
{
    public const string DefaultFailureReason =
        "The payout could not be completed. The money is back in your wallet.";

    private readonly IWalletRepository _walletRepository;
    private readonly IWalletTransactionRepository _walletTransactionRepository;

    public WithdrawalSettlement(
        IWalletRepository walletRepository,
        IWalletTransactionRepository walletTransactionRepository)
    {
        _walletRepository = walletRepository;
        _walletTransactionRepository = walletTransactionRepository;
    }

    /// <summary>The money reached the user: held balance becomes withdrawn.</summary>
    public async Task CompleteAsync(
        Withdrawal withdrawal,
        string? providerReference,
        decimal? actualProviderFee,
        CancellationToken cancellationToken)
    {
        Wallet wallet = await LoadWalletAsync(withdrawal, cancellationToken);

        withdrawal.Complete(providerReference, actualProviderFee);
        wallet.CompleteWithdrawal(withdrawal.Amount);

        await AddEntryAsync(
            wallet,
            withdrawal,
            WalletTransactionType.WithdrawalCompleted,
            $"Withdrawal {withdrawal.Reference} paid.",
            cancellationToken);
    }

    /// <summary>The payout failed for good: the held money goes back to available.</summary>
    public async Task FailAsync(
        Withdrawal withdrawal,
        string reason,
        string? internalDetail,
        CancellationToken cancellationToken)
    {
        Wallet wallet = await LoadWalletAsync(withdrawal, cancellationToken);

        withdrawal.Fail(reason, internalDetail);
        wallet.ReleaseWithdrawalHold(withdrawal.Amount);

        await AddEntryAsync(
            wallet,
            withdrawal,
            WalletTransactionType.WithdrawalReleased,
            $"Withdrawal {withdrawal.Reference} failed. Money returned.",
            cancellationToken);
    }

    public async Task RejectAsync(
        Withdrawal withdrawal,
        Guid reviewerId,
        string reason,
        CancellationToken cancellationToken)
    {
        Wallet wallet = await LoadWalletAsync(withdrawal, cancellationToken);

        withdrawal.Reject(reviewerId, reason);
        wallet.ReleaseWithdrawalHold(withdrawal.Amount);

        await AddEntryAsync(
            wallet,
            withdrawal,
            WalletTransactionType.WithdrawalReleased,
            $"Withdrawal {withdrawal.Reference} declined. Money returned.",
            cancellationToken);
    }

    public async Task CancelAsync(
        Withdrawal withdrawal,
        CancellationToken cancellationToken)
    {
        Wallet wallet = await LoadWalletAsync(withdrawal, cancellationToken);

        withdrawal.Cancel();
        wallet.ReleaseWithdrawalHold(withdrawal.Amount);

        await AddEntryAsync(
            wallet,
            withdrawal,
            WalletTransactionType.WithdrawalReleased,
            $"Withdrawal {withdrawal.Reference} cancelled. Money returned.",
            cancellationToken);
    }

    /// <summary>
    /// Applies a provider's report (from a webhook or a status check). Safe
    /// to call any number of times with the same news. A report that
    /// contradicts what we already settled (for example success after we
    /// recorded a failure and returned the money) is never applied: paying
    /// twice is worse than asking a human, so the withdrawal is flagged.
    /// </summary>
    public async Task<SettlementOutcome> ApplyProviderStateAsync(
        Withdrawal withdrawal,
        PayoutState state,
        string? providerReference,
        string? message,
        decimal? actualFee,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(withdrawal);

        switch (state)
        {
            case PayoutState.Succeeded:
                if (withdrawal.Status is WithdrawalStatus.Approved or WithdrawalStatus.Processing)
                {
                    await CompleteAsync(
                        withdrawal, providerReference, actualFee, cancellationToken);
                    return SettlementOutcome.Applied;
                }

                if (withdrawal.Status == WithdrawalStatus.Completed)
                {
                    return SettlementOutcome.Duplicate;
                }

                return Flag(
                    withdrawal,
                    $"Provider reported success but the withdrawal is {withdrawal.Status}. " +
                    "Check the provider before paying again.");

            case PayoutState.Failed:
                if (withdrawal.Status is WithdrawalStatus.Approved or WithdrawalStatus.Processing)
                {
                    await FailAsync(
                        withdrawal, DefaultFailureReason, message, cancellationToken);
                    return SettlementOutcome.Applied;
                }

                if (withdrawal.Status is WithdrawalStatus.Failed
                    or WithdrawalStatus.Rejected
                    or WithdrawalStatus.Cancelled)
                {
                    return SettlementOutcome.Duplicate;
                }

                if (withdrawal.Status == WithdrawalStatus.Completed)
                {
                    return Flag(
                        withdrawal,
                        "Provider reported failure after the withdrawal was marked paid. " +
                        "Check the provider.");
                }

                // Requested: the provider reports on something we never sent.
                return Flag(
                    withdrawal,
                    "Provider reported failure for a withdrawal that was never submitted.");

            default:
                return SettlementOutcome.Ignored;
        }
    }

    private static SettlementOutcome Flag(Withdrawal withdrawal, string note)
    {
        // Flag once; repeated webhooks must not keep growing the note.
        if (!withdrawal.NeedsAttention)
        {
            withdrawal.FlagNeedsAttention(note);
        }

        return SettlementOutcome.NeedsAttention;
    }

    private async Task<Wallet> LoadWalletAsync(
        Withdrawal withdrawal,
        CancellationToken cancellationToken)
    {
        return await _walletRepository.GetByIdAsync(
                withdrawal.WalletId, cancellationToken)
            ?? throw new KeyNotFoundException("Wallet was not found.");
    }

    private async Task AddEntryAsync(
        Wallet wallet,
        Withdrawal withdrawal,
        WalletTransactionType type,
        string description,
        CancellationToken cancellationToken)
    {
        await _walletTransactionRepository.AddAsync(
            new WalletTransaction(
                wallet.Id,
                wallet.UserId,
                type,
                withdrawal.Amount,
                cashbackId: null,
                description,
                wallet.AvailableBalance,
                wallet.PendingBalance,
                wallet.HeldBalance,
                withdrawal.Id),
            cancellationToken);
    }
}
