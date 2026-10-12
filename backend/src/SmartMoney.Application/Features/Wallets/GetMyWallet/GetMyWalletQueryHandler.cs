using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Wallets;

namespace SmartMoney.Application.Features.Wallets.GetMyWallet;

/// <summary>
/// Wallets are created lazily by the cashback pipeline, so a user who never
/// earned cashback has none — that reads as an all-zero wallet, never as an
/// error, and a GET must not create one.
/// </summary>
public sealed class GetMyWalletQueryHandler
    : IQueryHandler<GetMyWalletQuery, MyWalletResponse>
{
    private readonly IWalletRepository _walletRepository;

    public GetMyWalletQueryHandler(IWalletRepository walletRepository)
    {
        _walletRepository = walletRepository;
    }

    public async Task<MyWalletResponse> HandleAsync(
        GetMyWalletQuery query,
        CancellationToken cancellationToken)
    {
        var wallet = await _walletRepository.GetByUserIdAsync(
            query.UserId, cancellationToken);

        if (wallet is null)
        {
            return new MyWalletResponse();
        }

        return new MyWalletResponse
        {
            AvailableBalance = wallet.AvailableBalance,
            PendingBalance = wallet.PendingBalance,
            HeldBalance = wallet.HeldBalance,
            TotalEarned = wallet.TotalEarned,
            TotalWithdrawn = wallet.TotalWithdrawn
        };
    }
}
