using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Contracts.Withdrawals;

/// <summary>
/// The full payout destination. Only returned by the admin detail endpoint,
/// and only while the withdrawal is still open.
/// </summary>
public sealed class AdminWithdrawalDestination
{
    public string Method { get; set; } = string.Empty;

    public string BeneficiaryName { get; set; } = string.Empty;

    public string? UpiId { get; set; }

    public string? BankAccountNumber { get; set; }

    public string? IfscCode { get; set; }
}

public sealed class AdminWithdrawalResponse
{
    public Guid Id { get; set; }

    public string Reference { get; set; } = string.Empty;

    public Guid UserId { get; set; }

    public string UserFullName { get; set; } = string.Empty;

    public string UserEmail { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public decimal FeeTotal { get; set; }

    public decimal UserFee { get; set; }

    public decimal NetAmount { get; set; }

    public string Method { get; set; } = string.Empty;

    public string DestinationMasked { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;

    /// <summary>The work queue it is in: ToDecide, ToPay, InProgress or History.</summary>
    public string Queue { get; set; } = string.Empty;

    public string? ProviderName { get; set; }

    public string? ProviderReference { get; set; }

    public decimal? ActualProviderFee { get; set; }

    public string? FailureReason { get; set; }

    public string? LastError { get; set; }

    public int SubmissionAttempts { get; set; }

    public Guid? ReviewedByUserId { get; set; }

    public string? ReviewNote { get; set; }

    public bool NeedsAttention { get; set; }

    public DateTime RequestedAt { get; set; }

    public DateTime? ApprovedAt { get; set; }

    public DateTime? SubmittedAt { get; set; }

    public DateTime? SettledAt { get; set; }

    /// <summary>Null in lists, and null once the withdrawal has settled.</summary>
    public AdminWithdrawalDestination? Destination { get; set; }

    /// <summary>True when the withdrawal is open but its stored destination could not be decrypted.</summary>
    public bool DestinationUnreadable { get; set; }

    public static AdminWithdrawalResponse FromEntity(Withdrawal withdrawal)
    {
        ArgumentNullException.ThrowIfNull(withdrawal);

        return new AdminWithdrawalResponse
        {
            Id = withdrawal.Id,
            Reference = withdrawal.Reference,
            UserId = withdrawal.UserId,
            UserFullName = withdrawal.User?.FullName ?? string.Empty,
            UserEmail = withdrawal.User?.Email ?? string.Empty,
            Amount = withdrawal.Amount,
            FeeTotal = withdrawal.FeeTotal,
            UserFee = withdrawal.UserFee,
            NetAmount = withdrawal.NetAmount,
            Method = withdrawal.Method.ToString(),
            DestinationMasked = withdrawal.DestinationMasked,
            Status = withdrawal.Status.ToString(),
            Queue = WithdrawalQueues.Classify(withdrawal).ToString(),
            ProviderName = withdrawal.ProviderName,
            ProviderReference = withdrawal.ProviderReference,
            ActualProviderFee = withdrawal.ActualProviderFee,
            FailureReason = withdrawal.FailureReason,
            LastError = withdrawal.LastError,
            SubmissionAttempts = withdrawal.SubmissionAttempts,
            ReviewedByUserId = withdrawal.ReviewedByUserId,
            ReviewNote = withdrawal.ReviewNote,
            NeedsAttention = withdrawal.NeedsAttention,
            RequestedAt = withdrawal.CreatedAt,
            ApprovedAt = withdrawal.ApprovedAt,
            SubmittedAt = withdrawal.SubmittedAt,
            SettledAt = withdrawal.SettledAt
        };
    }
}
