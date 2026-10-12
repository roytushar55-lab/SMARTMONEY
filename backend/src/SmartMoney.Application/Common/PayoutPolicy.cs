namespace SmartMoney.Application.Common;

/// <summary>The money breakdown of one prospective withdrawal.</summary>
public sealed record PayoutQuote(
    decimal Amount,
    decimal FeeTotal,
    decimal UserFee,
    decimal NetAmount);

/// <summary>
/// The single place withdrawal limits and fees are computed, so the preview
/// the user sees and the amount actually paid can never disagree.
/// </summary>
public sealed class PayoutPolicy
{
    private readonly PayoutOptions _options;

    public PayoutPolicy(PayoutOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);

        if (options.MinimumAmount <= 0)
            throw new InvalidOperationException(
                "Payouts:MinimumAmount must be greater than zero.");

        if (options.MaximumAmount < options.MinimumAmount)
            throw new InvalidOperationException(
                "Payouts:MaximumAmount must not be below Payouts:MinimumAmount.");

        if (options.FlatFee < 0 || options.PercentFee < 0 || options.FeeTaxPercent < 0)
            throw new InvalidOperationException("Payout fees cannot be negative.");

        if (options.UserFeeSharePercent is < 0 or > 100)
            throw new InvalidOperationException(
                "Payouts:UserFeeSharePercent must be between 0 and 100.");

        if (options.MaxOpenWithdrawalsPerUser < 1)
            throw new InvalidOperationException(
                "Payouts:MaxOpenWithdrawalsPerUser must be at least 1.");

        if (options.MaxSubmissionAttempts < 1)
            throw new InvalidOperationException(
                "Payouts:MaxSubmissionAttempts must be at least 1.");

        if (options.WorkerIntervalSeconds < 5)
            throw new InvalidOperationException(
                "Payouts:WorkerIntervalSeconds must be at least 5.");

        if (options.WorkerBatchSize < 1)
            throw new InvalidOperationException(
                "Payouts:WorkerBatchSize must be at least 1.");

        if (options.ReconcileAfterMinutes < 1)
            throw new InvalidOperationException(
                "Payouts:ReconcileAfterMinutes must be at least 1.");

        _options = options;
    }

    public TimeSpan WorkerInterval => TimeSpan.FromSeconds(_options.WorkerIntervalSeconds);

    public int WorkerBatchSize => _options.WorkerBatchSize;

    public TimeSpan ReconcileAfter => TimeSpan.FromMinutes(_options.ReconcileAfterMinutes);

    public decimal MinimumAmount => _options.MinimumAmount;

    public decimal MaximumAmount => _options.MaximumAmount;

    public decimal UserFeeSharePercent => _options.UserFeeSharePercent;

    public bool RequireAdminApproval => _options.RequireAdminApproval;

    public int MaxOpenWithdrawalsPerUser => _options.MaxOpenWithdrawalsPerUser;

    public int MaxSubmissionAttempts => _options.MaxSubmissionAttempts;

    /// <summary>Returns a user-facing message when the amount is not allowed, otherwise null.</summary>
    public string? CheckAmount(decimal amount)
    {
        if (amount <= 0)
            return "Enter an amount greater than zero.";

        if (amount != Math.Round(amount, 2))
            return "The amount can have at most two decimal places.";

        if (amount < _options.MinimumAmount)
            return $"The minimum withdrawal is ₹{_options.MinimumAmount:0.##}.";

        if (amount > _options.MaximumAmount)
            return $"The maximum for one withdrawal is ₹{_options.MaximumAmount:0.##}.";

        return null;
    }

    public PayoutQuote Quote(decimal amount)
    {
        decimal beforeTax = _options.FlatFee + (amount * _options.PercentFee / 100m);
        decimal feeTotal = Round(beforeTax * (1m + (_options.FeeTaxPercent / 100m)));
        decimal userFee = Round(feeTotal * _options.UserFeeSharePercent / 100m);

        return new PayoutQuote(amount, feeTotal, userFee, amount - userFee);
    }

    private static decimal Round(decimal value) =>
        Math.Round(value, 2, MidpointRounding.AwayFromZero);
}
