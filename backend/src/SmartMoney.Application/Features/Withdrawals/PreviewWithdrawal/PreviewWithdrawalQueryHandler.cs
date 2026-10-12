using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.PreviewWithdrawal;

/// <summary>
/// Shows what a withdrawal would cost and whether it is allowed, without
/// changing anything. Problems come back as CanWithdraw = false and a
/// message, never as an error, so the screen can show them inline.
/// </summary>
public sealed class PreviewWithdrawalQueryHandler
    : IQueryHandler<PreviewWithdrawalQuery, WithdrawalPreviewResponse>
{
    private readonly IUserRepository _userRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly PayoutPolicy _policy;

    public PreviewWithdrawalQueryHandler(
        IUserRepository userRepository,
        IWalletRepository walletRepository,
        IWithdrawalRepository withdrawalRepository,
        PayoutPolicy policy)
    {
        _userRepository = userRepository;
        _walletRepository = walletRepository;
        _withdrawalRepository = withdrawalRepository;
        _policy = policy;
    }

    public async Task<WithdrawalPreviewResponse> HandleAsync(
        PreviewWithdrawalQuery query,
        CancellationToken cancellationToken)
    {
        User user = await _userRepository.GetByIdAsync(
                query.UserId, cancellationToken)
            ?? throw new KeyNotFoundException("Account was not found.");

        Wallet? wallet = await _walletRepository.GetByUserIdAsync(
            user.Id, cancellationToken);

        int open = await _withdrawalRepository.CountOpenByUserIdAsync(
            user.Id, cancellationToken);

        WithdrawalBlock? block = WithdrawalRules.CheckEligibility(
            _policy, user, wallet, open, query.Amount);

        var response = new WithdrawalPreviewResponse
        {
            Amount = query.Amount,
            UserFeeSharePercent = _policy.UserFeeSharePercent,
            MinimumAmount = _policy.MinimumAmount,
            MaximumAmount = _policy.MaximumAmount,
            AvailableBalance = wallet?.AvailableBalance ?? 0m,
            CanWithdraw = block is null,
            Message = block?.Message
        };

        // A fee only means something for an amount we would accept.
        if (_policy.CheckAmount(query.Amount) is null)
        {
            PayoutQuote quote = _policy.Quote(query.Amount);
            response.FeeTotal = quote.FeeTotal;
            response.UserFee = quote.UserFee;
            response.NetAmount = quote.NetAmount;
        }

        return response;
    }
}
