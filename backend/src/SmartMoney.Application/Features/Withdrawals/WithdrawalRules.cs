using System.Text.RegularExpressions;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Common;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals;

/// <summary>A reason a withdrawal cannot go ahead. Conflict maps to HTTP 409, otherwise 400.</summary>
public sealed record WithdrawalBlock(string Message, bool IsConflict);

/// <summary>
/// The checks shared by the preview (which reports them) and the request
/// (which enforces them), so the two can never disagree.
/// </summary>
public static class WithdrawalRules
{
    private static readonly Regex UpiPattern = new(
        @"^[a-z0-9._-]{2,256}@[a-z][a-z0-9]{1,63}$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private static readonly Regex AccountPattern = new(
        @"^[0-9]{9,18}$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private static readonly Regex IfscPattern = new(
        @"^[A-Z]{4}0[A-Z0-9]{6}$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private static readonly Regex NamePattern = new(
        // \p{M}: combining marks, so names in Devanagari, Tamil etc. (vowel
        // signs are marks, not letters) are not refused.
        @"^\p{L}[\p{L}\p{M} .'-]{1,99}$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    /// <summary>
    /// Amount, account standing, balance and open-withdrawal limit. Returns
    /// null when the user may proceed. The wallet may be null (never earned).
    /// </summary>
    public static WithdrawalBlock? CheckEligibility(
        PayoutPolicy policy,
        User user,
        Wallet? wallet,
        int openWithdrawals,
        decimal amount)
    {
        string? amountProblem = policy.CheckAmount(amount);

        if (amountProblem is not null)
        {
            return new WithdrawalBlock(amountProblem, IsConflict: false);
        }

        if (user.Status != UserStatus.Active || !user.IsActive)
        {
            return new WithdrawalBlock(
                "Your account cannot make withdrawals right now.", IsConflict: true);
        }

        if (!user.IsEmailVerified)
        {
            return new WithdrawalBlock(
                "Verify your email before withdrawing.", IsConflict: true);
        }

        if (openWithdrawals >= policy.MaxOpenWithdrawalsPerUser)
        {
            return new WithdrawalBlock(
                "You already have a withdrawal in progress. " +
                "Wait for it to finish or cancel it first.",
                IsConflict: true);
        }

        if (wallet is null || wallet.AvailableBalance < amount)
        {
            return new WithdrawalBlock(
                "Your available balance is lower than this amount.", IsConflict: true);
        }

        return null;
    }

    /// <summary>
    /// Validates and normalises the destination fields. Throws
    /// <see cref="ArgumentException"/> with a user-facing message.
    /// </summary>
    public static PayoutDestination BuildDestination(
        string method,
        string beneficiaryName,
        string? upiId,
        string? bankAccountNumber,
        string? ifscCode)
    {
        if (!Enum.TryParse(method?.Trim(), ignoreCase: true, out PayoutMethod parsed) ||
            !Enum.IsDefined(parsed))
        {
            throw new ArgumentException("Choose UPI or bank transfer.");
        }

        string name = (beneficiaryName ?? string.Empty).Trim();

        if (!NamePattern.IsMatch(name))
        {
            throw new ArgumentException("Enter the account holder's name.");
        }

        if (parsed == PayoutMethod.Upi)
        {
            string upi = (upiId ?? string.Empty).Trim().ToLowerInvariant();

            if (!UpiPattern.IsMatch(upi))
            {
                throw new ArgumentException("Enter a valid UPI ID, like name@bank.");
            }

            return new PayoutDestination(parsed, name, upi, null, null);
        }

        string account = (bankAccountNumber ?? string.Empty).Trim();

        if (!AccountPattern.IsMatch(account))
        {
            throw new ArgumentException(
                "Enter a valid bank account number (9 to 18 digits).");
        }

        string ifsc = (ifscCode ?? string.Empty).Trim().ToUpperInvariant();

        if (!IfscPattern.IsMatch(ifsc))
        {
            throw new ArgumentException("Enter a valid IFSC code, like HDFC0001234.");
        }

        return new PayoutDestination(parsed, name, null, account, ifsc);
    }
}
