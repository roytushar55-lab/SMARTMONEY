using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals;

/// <summary>
/// The response every withdrawal action (user cancel, admin approve, reject,
/// mark paid or failed, acknowledge) returns: the withdrawal's new status and
/// the wallet's resulting balances.
/// </summary>
internal static class WithdrawalDecisions
{
    public static async Task<WithdrawalDecisionResponse> BuildAsync(
        IWalletRepository walletRepository,
        Withdrawal withdrawal,
        CancellationToken cancellationToken)
    {
        Wallet wallet = await walletRepository.GetByIdAsync(
                withdrawal.WalletId, cancellationToken)
            ?? throw new KeyNotFoundException("Wallet was not found.");

        return new WithdrawalDecisionResponse
        {
            WithdrawalId = withdrawal.Id,
            Reference = withdrawal.Reference,
            Status = withdrawal.Status.ToString(),
            AvailableBalance = wallet.AvailableBalance,
            HeldBalance = wallet.HeldBalance
        };
    }
}
