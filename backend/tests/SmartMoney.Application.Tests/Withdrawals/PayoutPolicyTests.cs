using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Common;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class PayoutPolicyTests
{
    private static PayoutPolicy Policy(Action<PayoutOptions>? change = null)
    {
        var options = new PayoutOptions();
        change?.Invoke(options);
        return new PayoutPolicy(options);
    }

    // ---- amounts -------------------------------------------------------

    [Theory]
    [InlineData(250, true)]
    [InlineData(50000, true)]
    [InlineData(249.99, false)]
    [InlineData(50000.01, false)]
    [InlineData(0, false)]
    [InlineData(-100, false)]
    [InlineData(300.555, false)]
    public void Amount_limits(double amount, bool allowed)
    {
        Assert.Equal(allowed, Policy().CheckAmount((decimal)amount) is null);
    }

    [Fact]
    public void Limit_messages_are_user_facing()
    {
        Assert.Equal("The minimum withdrawal is ₹250.", Policy().CheckAmount(100m));
        Assert.Equal("The maximum for one withdrawal is ₹50000.", Policy().CheckAmount(60000m));
    }

    // ---- fees ----------------------------------------------------------

    [Fact]
    public void Defaults_charge_nothing()
    {
        var quote = Policy().Quote(500m);

        Assert.Equal(0m, quote.FeeTotal);
        Assert.Equal(0m, quote.UserFee);
        Assert.Equal(500m, quote.NetAmount);
    }

    [Fact]
    public void Fee_is_flat_plus_percent_plus_tax_and_user_pays_half()
    {
        // (10 + 1% of 1000) = 20, +18% = 23.60, half = 11.80
        var quote = Policy(o => { o.FlatFee = 10m; o.PercentFee = 1m; }).Quote(1000m);

        Assert.Equal(23.60m, quote.FeeTotal);
        Assert.Equal(11.80m, quote.UserFee);
        Assert.Equal(988.20m, quote.NetAmount);
    }

    [Fact]
    public void Rounding_goes_away_from_zero_to_paise_and_never_exceeds_the_total()
    {
        // 5.9 * 1.18 = 6.962 -> 6.96; half = 3.48
        var quote = Policy(o => o.FlatFee = 5.9m).Quote(300m);

        Assert.Equal(6.96m, quote.FeeTotal);
        Assert.Equal(3.48m, quote.UserFee);

        // 1.01 * 1.18 = 1.1918 -> 1.19; half = 0.595 -> 0.60 (not above total)
        var odd = Policy(o => o.FlatFee = 1.01m).Quote(300m);
        Assert.Equal(1.19m, odd.FeeTotal);
        Assert.Equal(0.60m, odd.UserFee);
        Assert.True(odd.UserFee <= odd.FeeTotal);
        Assert.Equal(300m - odd.UserFee, odd.NetAmount);
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(100, 118)]
    public void User_share_can_be_none_or_everything(double share, double expectedUserFee)
    {
        var quote = Policy(o => { o.FlatFee = 100m; o.UserFeeSharePercent = (decimal)share; })
            .Quote(1000m);

        Assert.Equal(118m, quote.FeeTotal);
        Assert.Equal((decimal)expectedUserFee, quote.UserFee);
    }

    // ---- bad settings --------------------------------------------------

    public static IEnumerable<object[]> BadSettings() => new[]
    {
        new object[] { (Action<PayoutOptions>)(o => o.MinimumAmount = 0) },
        new object[] { (Action<PayoutOptions>)(o => { o.MinimumAmount = 500; o.MaximumAmount = 100; }) },
        new object[] { (Action<PayoutOptions>)(o => o.FlatFee = -1) },
        new object[] { (Action<PayoutOptions>)(o => o.PercentFee = -1) },
        new object[] { (Action<PayoutOptions>)(o => o.FeeTaxPercent = -1) },
        new object[] { (Action<PayoutOptions>)(o => o.UserFeeSharePercent = 101) },
        new object[] { (Action<PayoutOptions>)(o => o.UserFeeSharePercent = -1) },
        new object[] { (Action<PayoutOptions>)(o => o.MaxOpenWithdrawalsPerUser = 0) },
        new object[] { (Action<PayoutOptions>)(o => o.MaxSubmissionAttempts = 0) },
        new object[] { (Action<PayoutOptions>)(o => o.WorkerIntervalSeconds = 1) },
        new object[] { (Action<PayoutOptions>)(o => o.WorkerBatchSize = 0) },
        new object[] { (Action<PayoutOptions>)(o => o.ReconcileAfterMinutes = 0) },
    };

    [Theory]
    [MemberData(nameof(BadSettings))]
    public void Bad_settings_are_refused_at_construction(Action<PayoutOptions> change)
    {
        Assert.Throws<InvalidOperationException>(() => Policy(change));
    }

    // ---- destination masking and shape ---------------------------------

    [Fact]
    public void Masks_hide_everything_sensitive()
    {
        var upi = new PayoutDestination(PayoutMethod.Upi, "A B", "asha@okhdfc", null, null);
        var bank = new PayoutDestination(
            PayoutMethod.BankTransfer, "A B", null, "123456789012", "HDFC0001234");

        Assert.Equal("as****@okhdfc", upi.Mask());
        Assert.Equal("HDFC0001234 ****9012", bank.Mask());
    }

    [Theory]
    [InlineData("a@upi", "a****@upi")]
    [InlineData("ab@upi", "a****@upi")]
    [InlineData("abc@upi", "ab****@upi")]
    [InlineData("noatsign", "****")]
    [InlineData("", "****")]
    public void Upi_masking_edge_cases(string id, string expected)
    {
        Assert.Equal(expected,
            new PayoutDestination(PayoutMethod.Upi, "n", id, null, null).Mask());
    }

    [Fact]
    public void Short_account_numbers_are_masked_without_overrun()
    {
        var bank = new PayoutDestination(PayoutMethod.BankTransfer, "n", null, "12", null);

        Assert.Equal("****12", bank.Mask());
    }
}
