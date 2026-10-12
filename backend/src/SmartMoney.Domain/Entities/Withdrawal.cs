using System.Security.Cryptography;
using SmartMoney.Domain.Common;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Domain.Entities;

/// <summary>
/// A user's request to move wallet money out to a bank account or UPI ID.
/// The entity is provider-agnostic: it records what must be paid and where
/// the payout stands, never anything specific to one vendor.
///
/// Money rules (enforced by the handlers, mirrored in the ledger):
/// Amount is held on the wallet while the withdrawal is open. The user
/// receives NetAmount = Amount - UserFee; SmartMoney absorbs the rest of the
/// provider fee.
/// </summary>
public class Withdrawal : BaseEntity
{
    private const int MaxTextLength = 500;

    public Guid UserId { get; private set; }

    public Guid WalletId { get; private set; }

    /// <summary>
    /// Our unique id for the payout. Sent to the provider as the idempotency
    /// key, so submitting the same withdrawal twice can never pay twice.
    /// </summary>
    public string Reference { get; private set; } = string.Empty;

    /// <summary>Gross amount taken from the wallet.</summary>
    public decimal Amount { get; private set; }

    /// <summary>Total provider fee (including tax), as estimated at request time.</summary>
    public decimal FeeTotal { get; private set; }

    /// <summary>The user's share of <see cref="FeeTotal"/>, deducted from the payout.</summary>
    public decimal UserFee { get; private set; }

    /// <summary>What the user actually receives.</summary>
    public decimal NetAmount { get; private set; }

    public PayoutMethod Method { get; private set; }

    /// <summary>Safe to show anywhere, e.g. "HDFC0001234 ****6789" or "ab****@upi".</summary>
    public string DestinationMasked { get; private set; } = string.Empty;

    /// <summary>
    /// The full destination, encrypted. Cleared as soon as the withdrawal
    /// reaches a terminal state, so bank details are not kept longer than
    /// needed.
    /// </summary>
    public string? DestinationProtected { get; private set; }

    public WithdrawalStatus Status { get; private set; } = WithdrawalStatus.Requested;

    public string? ProviderName { get; private set; }

    /// <summary>The provider's own id, or the bank UTR for a manual payout.</summary>
    public string? ProviderReference { get; private set; }

    /// <summary>The fee the provider really charged, when it reports one.</summary>
    public decimal? ActualProviderFee { get; private set; }

    /// <summary>Why a terminal failure happened. Shown to the user, so keep it plain.</summary>
    public string? FailureReason { get; private set; }

    /// <summary>The most recent temporary submission problem. Not shown to the user.</summary>
    public string? LastError { get; private set; }

    public int SubmissionAttempts { get; private set; }

    public Guid? ReviewedByUserId { get; private set; }

    public string? ReviewNote { get; private set; }

    /// <summary>
    /// Set when the provider reports something that does not fit our records
    /// (for example success after we recorded a failure). An admin must look.
    /// </summary>
    public bool NeedsAttention { get; private set; }

    public DateTime? ApprovedAt { get; private set; }

    /// <summary>
    /// When we first set out to send this to the provider. Saved BEFORE the
    /// provider is called, so "set" means the money may already be on its way.
    /// </summary>
    public DateTime? SubmittedAt { get; private set; }

    /// <summary>True once a payout has been, or may have been, sent to a provider.</summary>
    public bool SubmissionStarted => SubmittedAt is not null || SubmissionAttempts > 0;

    /// <summary>When the withdrawal reached a terminal state.</summary>
    public DateTime? SettledAt { get; private set; }

    public User User { get; private set; } = null!;

    public Wallet Wallet { get; private set; } = null!;

    public bool IsOpen => Status is WithdrawalStatus.Requested
        or WithdrawalStatus.Approved
        or WithdrawalStatus.Processing;

    public bool IsTerminal => !IsOpen;

    private Withdrawal()
    {
    }

    public Withdrawal(
        Guid userId,
        Guid walletId,
        string reference,
        decimal amount,
        decimal feeTotal,
        decimal userFee,
        PayoutMethod method,
        string destinationMasked,
        string destinationProtected)
    {
        if (string.IsNullOrWhiteSpace(reference))
            throw new ArgumentException("Reference is required.");

        if (amount <= 0)
            throw new ArgumentException("Amount must be greater than zero.");

        if (feeTotal < 0 || userFee < 0 || userFee > feeTotal)
            throw new ArgumentException("Fee amounts are invalid.");

        if (amount - userFee <= 0)
            throw new ArgumentException("The payout would be zero after fees.");

        if (string.IsNullOrWhiteSpace(destinationMasked) ||
            string.IsNullOrWhiteSpace(destinationProtected))
            throw new ArgumentException("A payout destination is required.");

        UserId = userId;
        WalletId = walletId;
        Reference = reference.Trim();
        Amount = amount;
        FeeTotal = feeTotal;
        UserFee = userFee;
        NetAmount = amount - userFee;
        Method = method;
        DestinationMasked = destinationMasked;
        DestinationProtected = destinationProtected;
    }

    /// <summary>
    /// A fresh reference such as WD20261011K7QM2XA9PD: letters and digits
    /// only, so every provider accepts it as an idempotency key.
    /// </summary>
    public static string NewReference(DateTime? utcNow = null)
    {
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

        char[] suffix = new char[10];
        for (int i = 0; i < suffix.Length; i++)
        {
            suffix[i] = alphabet[RandomNumberGenerator.GetInt32(alphabet.Length)];
        }

        return $"WD{(utcNow ?? DateTime.UtcNow):yyyyMMdd}{new string(suffix)}";
    }

    /// <summary>Clears the way for payout. <paramref name="reviewerId"/> is null for automatic approval.</summary>
    public void Approve(Guid? reviewerId)
    {
        if (Status != WithdrawalStatus.Requested)
            throw new InvalidOperationException(
                "Only a requested withdrawal can be approved.");

        Status = WithdrawalStatus.Approved;
        ReviewedByUserId = reviewerId;
        ApprovedAt = DateTime.UtcNow;
        MarkAsUpdated();
    }

    public void Reject(Guid reviewerId, string reason)
    {
        if (Status is not (WithdrawalStatus.Requested or WithdrawalStatus.Approved))
            throw new InvalidOperationException(
                "Only a requested or approved withdrawal can be rejected.");

        if (string.IsNullOrWhiteSpace(reason))
            throw new ArgumentException("A reason is required.");

        Status = WithdrawalStatus.Rejected;
        ReviewedByUserId = reviewerId;
        ReviewNote = Trim(reason);
        FailureReason = ReviewNote;
        Settle();
    }

    public void Cancel()
    {
        if (Status != WithdrawalStatus.Requested)
            throw new InvalidOperationException(
                "A withdrawal can only be cancelled before it is approved.");

        Status = WithdrawalStatus.Cancelled;
        Settle();
    }

    /// <summary>
    /// Written and saved immediately before the provider is called. It
    /// changes the row, so a reject or settle that loaded the withdrawal
    /// earlier loses the concurrency check instead of racing the payout; and
    /// from here on the withdrawal counts as sent (see
    /// <see cref="SubmissionStarted"/>).
    /// </summary>
    public void BeginSubmission(string providerName)
    {
        if (Status != WithdrawalStatus.Approved)
            throw new InvalidOperationException(
                "Only an approved withdrawal can be submitted.");

        if (string.IsNullOrWhiteSpace(providerName))
            throw new ArgumentException("Provider name is required.");

        ProviderName = providerName.Trim();
        SubmittedAt ??= DateTime.UtcNow;
        MarkAsUpdated();
    }

    /// <summary>Records that the provider accepted the payout.</summary>
    public void MarkSubmitted(string providerName, string? providerReference)
    {
        if (Status != WithdrawalStatus.Approved)
            throw new InvalidOperationException(
                "Only an approved withdrawal can be submitted.");

        if (string.IsNullOrWhiteSpace(providerName))
            throw new ArgumentException("Provider name is required.");

        Status = WithdrawalStatus.Processing;
        ProviderName = providerName.Trim();
        ProviderReference = string.IsNullOrWhiteSpace(providerReference)
            ? null
            : providerReference.Trim();
        SubmissionAttempts++;
        SubmittedAt ??= DateTime.UtcNow;
        LastError = null;
        MarkAsUpdated();
    }

    /// <summary>A temporary problem submitting; the withdrawal stays Approved to be retried.</summary>
    public void RecordSubmissionFailure(string providerName, string error)
    {
        if (Status != WithdrawalStatus.Approved)
            throw new InvalidOperationException(
                "Only an approved withdrawal can be submitted.");

        ProviderName = string.IsNullOrWhiteSpace(providerName)
            ? ProviderName
            : providerName.Trim();
        SubmissionAttempts++;
        LastError = Trim(error);
        MarkAsUpdated();
    }

    /// <summary>
    /// The money reached the user. For a manual payout
    /// <paramref name="providerReference"/> is the bank's UTR.
    /// </summary>
    public void Complete(string? providerReference, decimal? actualProviderFee)
    {
        if (Status is not (WithdrawalStatus.Approved or WithdrawalStatus.Processing))
            throw new InvalidOperationException(
                "Only an approved or processing withdrawal can be completed.");

        if (actualProviderFee is < 0)
            throw new ArgumentException("Provider fee cannot be negative.");

        if (!string.IsNullOrWhiteSpace(providerReference))
            ProviderReference = providerReference.Trim();

        ActualProviderFee = actualProviderFee;
        Status = WithdrawalStatus.Completed;
        LastError = null;
        Settle();
    }

    /// <summary>
    /// The payout failed. <paramref name="reason"/> is shown to the user;
    /// <paramref name="internalDetail"/> (a provider's raw message, say) is
    /// kept for admins only.
    /// </summary>
    public void Fail(string reason, string? internalDetail = null)
    {
        if (Status is not (WithdrawalStatus.Approved or WithdrawalStatus.Processing))
            throw new InvalidOperationException(
                "Only an approved or processing withdrawal can be failed.");

        if (string.IsNullOrWhiteSpace(reason))
            throw new ArgumentException("A reason is required.");

        Status = WithdrawalStatus.Failed;
        FailureReason = Trim(reason);

        if (!string.IsNullOrWhiteSpace(internalDetail))
            LastError = Trim(internalDetail);

        Settle();
    }

    /// <summary>
    /// Notes that the provider was asked about a processing payout and it is
    /// still in flight, so it is not asked again straight away.
    /// <paramref name="error"/> is a problem reaching the provider, if any.
    /// </summary>
    public void RecordStatusCheck(string? error = null)
    {
        if (!string.IsNullOrWhiteSpace(error))
            LastError = Trim(error);

        MarkAsUpdated();
    }

    public void FlagNeedsAttention(string note)
    {
        // Flagging for a reason already on the note changes nothing, so a
        // repeated report cannot fill the 500-character note with duplicates.
        if (NeedsAttention &&
            ReviewNote is not null &&
            ReviewNote.Contains(Trim(note), StringComparison.Ordinal))
        {
            return;
        }

        NeedsAttention = true;
        ReviewNote = Trim(string.IsNullOrWhiteSpace(ReviewNote)
            ? note
            : $"{ReviewNote} | {note}");
        MarkAsUpdated();
    }

    public void ClearNeedsAttention()
    {
        NeedsAttention = false;
        MarkAsUpdated();
    }

    private void Settle()
    {
        // Reaching a final state resolves whatever was flagged. A report that
        // contradicts this outcome later flags it again.
        NeedsAttention = false;
        DestinationProtected = null;
        SettledAt = DateTime.UtcNow;
        MarkAsUpdated();
    }

    private static string Trim(string value)
    {
        string trimmed = value.Trim();
        return trimmed.Length <= MaxTextLength
            ? trimmed
            : trimmed[..MaxTextLength];
    }
}
