using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.CancelWithdrawal;

/// <summary>
/// The user withdraws their own request. Only possible before it is
/// approved; after that the payout may already be on its way.
/// </summary>
public sealed class CancelWithdrawalCommandHandler
    : ICommandHandler<CancelWithdrawalCommand, WithdrawalDecisionResponse>
{
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly WithdrawalSettlement _settlement;
    private readonly IUnitOfWork _unitOfWork;

    public CancelWithdrawalCommandHandler(
        IWithdrawalRepository withdrawalRepository,
        IWalletRepository walletRepository,
        WithdrawalSettlement settlement,
        IUnitOfWork unitOfWork)
    {
        _withdrawalRepository = withdrawalRepository;
        _walletRepository = walletRepository;
        _settlement = settlement;
        _unitOfWork = unitOfWork;
    }

    public async Task<WithdrawalDecisionResponse> HandleAsync(
        CancelWithdrawalCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        Withdrawal withdrawal = await _withdrawalRepository.GetByIdAsync(
                command.WithdrawalId, cancellationToken)
            ?? throw new KeyNotFoundException("Withdrawal was not found.");

        // Someone else's withdrawal looks exactly like a missing one.
        if (withdrawal.UserId != command.UserId)
        {
            throw new KeyNotFoundException("Withdrawal was not found.");
        }

        await _settlement.CancelAsync(withdrawal, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return await WithdrawalDecisions.BuildAsync(
            _walletRepository, withdrawal, cancellationToken);
    }
}
