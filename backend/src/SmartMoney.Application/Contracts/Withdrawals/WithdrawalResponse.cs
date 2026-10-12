using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Contracts.Withdrawals;

/// <summary>A withdrawal as the user sees it. Never contains full bank details.</summary>
public sealed class WithdrawalResponse
{
    public Guid Id { get; set; }

    public string Reference { get; set; } = string.Empty;

    /// <summary>Taken from the wallet.</summary>
    public decimal Amount { get; set; }

    public decimal FeeTotal { get; set; }

    /// <summary>The user's share of the fee, deducted from the payout.</summary>
    public decimal UserFee { get; set; }

    /// <summary>What the user receives.</summary>
    public decimal NetAmount { get; set; }

    public string Method { get; set; } = string.Empty;

    /// <summary>For example "ab****@okhdfc" or "HDFC0001234 ****6789".</summary>
    public string Destination { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;

    /// <summary>Why it failed or was declined. Null otherwise.</summary>
    public string? FailureReason { get; set; }

    /// <summary>The bank or provider reference once paid. Null before that.</summary>
    public string? TransactionReference { get; set; }

    public bool CanCancel { get; set; }

    public DateTime RequestedAt { get; set; }

    public DateTime? SettledAt { get; set; }

    public static WithdrawalResponse FromEntity(Withdrawal withdrawal)
    {
        ArgumentNullException.ThrowIfNull(withdrawal);

        return new WithdrawalResponse
        {
            Id = withdrawal.Id,
            Reference = withdrawal.Reference,
            Amount = withdrawal.Amount,
            FeeTotal = withdrawal.FeeTotal,
            UserFee = withdrawal.UserFee,
            NetAmount = withdrawal.NetAmount,
            Method = withdrawal.Method.ToString(),
            Destination = withdrawal.DestinationMasked,
            Status = withdrawal.Status.ToString(),
            FailureReason = withdrawal.FailureReason,
            TransactionReference = withdrawal.Status == WithdrawalStatus.Completed
                ? withdrawal.ProviderReference
                : null,
            CanCancel = withdrawal.Status == WithdrawalStatus.Requested,
            RequestedAt = withdrawal.CreatedAt,
            SettledAt = withdrawal.SettledAt
        };
    }
}
