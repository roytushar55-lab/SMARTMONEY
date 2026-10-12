namespace SmartMoney.Application.Features.Cashbacks;

/// <summary>
/// The rule for when an admin may approve a cashback: only once the affiliate
/// network says the sale is validated (the merchant accepted it after the
/// return period) or already paid. While the network still says pending, or
/// has rejected, cancelled or reversed the sale, approving would credit money
/// that may be taken back. A SuperAdmin may override with a recorded reason.
/// </summary>
public static class CashbackApprovalPolicy
{
    /// <summary>Network statuses (lower case) that allow approval.</summary>
    private static readonly HashSet<string> Approvable = new(StringComparer.Ordinal)
    {
        "validated",
        "paid"
    };

    /// <summary>
    /// Null when the cashback may be approved; otherwise a plain-language
    /// reason it may not. <paramref name="networkStatus"/> is the network's
    /// own word for the sale, or null when it is not known.
    /// </summary>
    public static string? Refusal(string? networkStatus)
    {
        string status = (networkStatus ?? string.Empty).Trim().ToLowerInvariant();

        if (Approvable.Contains(status))
        {
            return null;
        }

        return status switch
        {
            "pending" =>
                "The affiliate network still reports this sale as pending, so the return " +
                "period is not over. It can be approved once the network marks it validated.",

            "rejected" or "cancelled" or "canceled" =>
                $"The affiliate network reports this sale as {status}, so it should not be " +
                "approved. Reject it, or ask a SuperAdmin to approve it anyway with a reason.",

            "reversed" =>
                "The affiliate network reports this sale as reversed, so it should not be " +
                "approved. Reverse or reject it, or ask a SuperAdmin to approve it anyway with a reason.",

            "" =>
                "The affiliate network status of this sale is not known, so it cannot be " +
                "approved yet.",

            _ =>
                $"The affiliate network reports this sale as '{status}', which is not a " +
                "validated status, so it cannot be approved yet."
        };
    }
}
