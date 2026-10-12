using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals;

/// <summary>Shared pieces of the admin handlers.</summary>
internal static class WithdrawalAdminSupport
{
    /// <summary>
    /// An admin may settle a withdrawal by hand when nothing automatic is
    /// responsible for it: always with the manual provider, and with an
    /// automatic provider only once it needs attention or its retries are
    /// used up. Otherwise the provider could pay as well, and the user would
    /// be paid twice.
    /// </summary>
    public static void EnsureManualSettlementAllowed(
        IPayoutProvider provider,
        Withdrawal withdrawal,
        int maxSubmissionAttempts)
    {
        if (!provider.SupportsAutomaticPayout)
        {
            return;
        }

        if (!withdrawal.NeedsAttention && !RetriesUsedUp(withdrawal, maxSubmissionAttempts))
        {
            throw new InvalidOperationException(
                "This payout is handled automatically by the payment provider. " +
                "It can only be settled by hand once it needs attention.");
        }
    }

    /// <summary>
    /// A reject refunds the user, so it is only safe while the provider has
    /// never been asked to pay: once a submission has started (even one that
    /// timed out, which may have reached the provider) the provider could
    /// still pay, and refunding would pay the user twice. After that a reject
    /// is allowed only when the withdrawal needs attention or its retries are
    /// used up, which is when an admin is expected to check the provider.
    /// </summary>
    public static void EnsureRejectAllowed(
        IPayoutProvider provider,
        Withdrawal withdrawal,
        int maxSubmissionAttempts)
    {
        if (!provider.SupportsAutomaticPayout || !withdrawal.SubmissionStarted)
        {
            return;
        }

        if (!withdrawal.NeedsAttention && !RetriesUsedUp(withdrawal, maxSubmissionAttempts))
        {
            throw new InvalidOperationException(
                "This payout has already been sent to the payment provider, " +
                "so it can no longer be declined here. It can be declined once " +
                "it needs attention.");
        }
    }

    private static bool RetriesUsedUp(Withdrawal withdrawal, int maxSubmissionAttempts)
    {
        return withdrawal.Status == WithdrawalStatus.Approved
            && withdrawal.SubmissionAttempts >= maxSubmissionAttempts;
    }
}
