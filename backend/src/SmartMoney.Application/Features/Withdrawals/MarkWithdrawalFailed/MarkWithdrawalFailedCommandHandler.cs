using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.MarkWithdrawalFailed;

/// <summary>
/// Admin records that an approved payout could not be made (for example the
/// bank returned it). The held money goes back to the user and the reason is
/// shown to them. A withdrawal nobody has approved is rejected, not failed.
/// </summary>
public sealed class MarkWithdrawalFailedCommandHandler
    : ICommandHandler<MarkWithdrawalFailedCommand, WithdrawalDecisionResponse?>
{
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IPayoutProvider _provider;
    private readonly PayoutPolicy _policy;
    private readonly WithdrawalSettlement _settlement;
    private readonly IUnitOfWork _unitOfWork;

    public MarkWithdrawalFailedCommandHandler(
        IWithdrawalRepository withdrawalRepository,
        IWalletRepository walletRepository,
        IPayoutProvider provider,
        PayoutPolicy policy,
        WithdrawalSettlement settlement,
        IUnitOfWork unitOfWork)
    {
        _withdrawalRepository = withdrawalRepository;
        _walletRepository = walletRepository;
        _provider = provider;
        _policy = policy;
        _settlement = settlement;
        _unitOfWork = unitOfWork;
    }

    public async Task<WithdrawalDecisionResponse?> HandleAsync(
        MarkWithdrawalFailedCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        if (string.IsNullOrWhiteSpace(command.Reason))
        {
            throw new ArgumentException("A reason is required.");
        }

        Withdrawal? withdrawal = await _withdrawalRepository.GetByIdAsync(
            command.WithdrawalId, cancellationToken);

        if (withdrawal is null)
        {
            return null;
        }

        WithdrawalAdminSupport.EnsureManualSettlementAllowed(
            _provider, withdrawal, _policy.MaxSubmissionAttempts);

        await _settlement.FailAsync(
            withdrawal, command.Reason, internalDetail: null, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return await WithdrawalDecisions.BuildAsync(
            _walletRepository, withdrawal, cancellationToken);
    }
}
