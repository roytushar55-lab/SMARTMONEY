namespace SmartMoney.Application.Contracts.Withdrawals;

/// <summary>
/// What the withdrawal screen shows before the user confirms: the fee, the
/// user's share of it, and the amount they will actually receive.
/// </summary>
public sealed class WithdrawalPreviewResponse
{
    public decimal Amount { get; set; }

    public decimal FeeTotal { get; set; }

    public decimal UserFee { get; set; }

    public decimal NetAmount { get; set; }

    public decimal UserFeeSharePercent { get; set; }

    public decimal MinimumAmount { get; set; }

    public decimal MaximumAmount { get; set; }

    public decimal AvailableBalance { get; set; }

    public bool CanWithdraw { get; set; }

    /// <summary>The reason CanWithdraw is false. Null when it is true.</summary>
    public string? Message { get; set; }
}
