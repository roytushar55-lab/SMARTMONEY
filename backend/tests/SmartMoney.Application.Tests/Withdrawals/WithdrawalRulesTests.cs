using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Common;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Withdrawals;

public sealed class WithdrawalRulesTests
{
    // ---- destination validation ---------------------------------------

    [Theory]
    [InlineData("name@okhdfc")]
    [InlineData("first.last-1_x@ybl")]
    [InlineData("Name@OkHdfc")]
    public void Valid_upi_ids_are_accepted_and_lowercased(string upi)
    {
        var d = WithdrawalRules.BuildDestination("Upi", "Asha Rao", upi, null, null);

        Assert.Equal(upi.ToLowerInvariant(), d.UpiId);
        Assert.Equal(PayoutMethod.Upi, d.Method);
    }

    [Theory]
    [InlineData("")]
    [InlineData("noat")]
    [InlineData("@bank")]
    [InlineData("a@bank")]            // handle too short
    [InlineData("name@")]
    [InlineData("na me@bank")]
    [InlineData("name@bank@bank")]
    [InlineData("name@1bank")]
    public void Invalid_upi_ids_are_refused(string upi)
    {
        Assert.Throws<ArgumentException>(() =>
            WithdrawalRules.BuildDestination("Upi", "Asha Rao", upi, null, null));
    }

    [Theory]
    [InlineData("123456789")]
    [InlineData("123456789012345678")]
    public void Valid_account_numbers(string account)
    {
        var d = WithdrawalRules.BuildDestination(
            "BankTransfer", "Asha Rao", null, account, "hdfc0001234");

        Assert.Equal(account, d.BankAccountNumber);
        Assert.Equal("HDFC0001234", d.IfscCode);
    }

    [Theory]
    [InlineData("12345678")]               // 8 digits
    [InlineData("1234567890123456789")]    // 19 digits
    [InlineData("12345678a")]
    [InlineData("1234 5678 9012")]
    public void Invalid_account_numbers(string account)
    {
        Assert.Throws<ArgumentException>(() =>
            WithdrawalRules.BuildDestination(
                "BankTransfer", "Asha Rao", null, account, "HDFC0001234"));
    }

    [Theory]
    [InlineData("HDFC1001234")]   // fifth char must be 0
    [InlineData("HDF0001234")]
    [InlineData("HDFC000123")]
    [InlineData("1234C0001234")]
    [InlineData("")]
    public void Invalid_ifsc(string ifsc)
    {
        Assert.Throws<ArgumentException>(() =>
            WithdrawalRules.BuildDestination(
                "BankTransfer", "Asha Rao", null, "123456789012", ifsc));
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData("1234")]
    [InlineData("A")]
    public void Invalid_names(string name)
    {
        Assert.Throws<ArgumentException>(() =>
            WithdrawalRules.BuildDestination("Upi", name, "name@bank", null, null));
    }

    [Theory]
    [InlineData("Asha Rao")]
    [InlineData("D'Souza-Pinto Jr.")]
    [InlineData("आशा राव")]
    public void Real_names_are_accepted(string name)
    {
        Assert.Equal(name.Trim(),
            WithdrawalRules.BuildDestination("Upi", name, "name@bank", null, null)
                .BeneficiaryName);
    }

    [Theory]
    [InlineData("")]
    [InlineData("Cash")]
    [InlineData("0")]
    [InlineData("99")]
    public void Unknown_methods_are_refused(string method)
    {
        Assert.Throws<ArgumentException>(() =>
            WithdrawalRules.BuildDestination(method, "Asha Rao", "name@bank", null, null));
    }

    [Fact]
    public void Fields_for_the_other_method_are_dropped()
    {
        var d = WithdrawalRules.BuildDestination(
            "Upi", "Asha Rao", "name@bank", "123456789012", "HDFC0001234");

        Assert.Null(d.BankAccountNumber);
        Assert.Null(d.IfscCode);
    }

    // ---- eligibility ---------------------------------------------------

    private static User ActiveUser()
    {
        var user = new User("A B", "a@example.com", "9876543210", "hash", Guid.NewGuid());
        user.ActivateAccount();
        user.VerifyEmail();
        return user;
    }

    private static Wallet Funded(Guid userId, decimal amount)
    {
        var wallet = new Wallet(userId);
        wallet.AddPendingCashback(amount);
        wallet.ApproveCashback(amount);
        return wallet;
    }

    private static readonly PayoutPolicy Policy = new(new PayoutOptions());

    [Fact]
    public void Eligible_user_passes()
    {
        var user = ActiveUser();

        Assert.Null(WithdrawalRules.CheckEligibility(
            Policy, user, Funded(user.Id, 500m), 0, 300m));
    }

    [Fact]
    public void Amount_problem_is_a_bad_request_not_a_conflict()
    {
        var user = ActiveUser();

        var block = WithdrawalRules.CheckEligibility(
            Policy, user, Funded(user.Id, 500m), 0, 10m);

        Assert.False(block!.IsConflict);
    }

    [Fact]
    public void Account_standing_problems_are_conflicts()
    {
        var suspended = ActiveUser();
        suspended.SuspendAccount();
        var unverified = new User("A B", "b@example.com", "9876543211", "hash", Guid.NewGuid());
        unverified.ActivateAccount();
        var inactive = ActiveUser();
        inactive.Deactivate();

        foreach (var user in new[] { suspended, unverified, inactive })
        {
            var block = WithdrawalRules.CheckEligibility(
                Policy, user, Funded(user.Id, 500m), 0, 300m);

            Assert.True(block!.IsConflict);
        }
    }

    [Fact]
    public void Open_withdrawal_limit_follows_the_setting()
    {
        var user = ActiveUser();
        var wallet = Funded(user.Id, 5000m);
        var two = new PayoutPolicy(new PayoutOptions { MaxOpenWithdrawalsPerUser = 2 });

        Assert.NotNull(WithdrawalRules.CheckEligibility(Policy, user, wallet, 1, 300m));
        Assert.Null(WithdrawalRules.CheckEligibility(two, user, wallet, 1, 300m));
        Assert.NotNull(WithdrawalRules.CheckEligibility(two, user, wallet, 2, 300m));
    }

    [Fact]
    public void Missing_wallet_or_short_balance_is_a_conflict()
    {
        var user = ActiveUser();

        Assert.True(WithdrawalRules.CheckEligibility(Policy, user, null, 0, 300m)!.IsConflict);
        Assert.True(WithdrawalRules.CheckEligibility(
            Policy, user, Funded(user.Id, 299m), 0, 300m)!.IsConflict);
    }

    [Fact]
    public void Held_money_does_not_count_as_available()
    {
        var user = ActiveUser();
        var wallet = Funded(user.Id, 500m);
        wallet.HoldForWithdrawal(400m);

        Assert.NotNull(WithdrawalRules.CheckEligibility(Policy, user, wallet, 0, 250m));
    }
}
