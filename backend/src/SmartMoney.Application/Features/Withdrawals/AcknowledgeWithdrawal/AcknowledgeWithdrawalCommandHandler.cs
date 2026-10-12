using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.AcknowledgeWithdrawal;

/// <summary>
/// Admin confirms they have looked at a flagged withdrawal and dealt with it
/// outside the system (for example a provider reported success after the
/// money had already been returned), so it leaves the needs-attention list.
/// Changes no money.
/// </summary>
public sealed class AcknowledgeWithdrawalCommandHandler
    : ICommandHandler<AcknowledgeWithdrawalCommand, WithdrawalDecisionResponse?>
{
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IUnitOfWork _unitOfWork;

    public AcknowledgeWithdrawalCommandHandler(
        IWithdrawalRepository withdrawalRepository,
        IWalletRepository walletRepository,
        IUnitOfWork unitOfWork)
    {
        _withdrawalRepository = withdrawalRepository;
        _walletRepository = walletRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<WithdrawalDecisionResponse?> HandleAsync(
        AcknowledgeWithdrawalCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        Withdrawal? withdrawal = await _withdrawalRepository.GetByIdAsync(
            command.WithdrawalId, cancellationToken);

        if (withdrawal is null)
        {
            return null;
        }

        if (withdrawal.NeedsAttention)
        {
            withdrawal.ClearNeedsAttention();
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }

        return await WithdrawalDecisions.BuildAsync(
            _walletRepository, withdrawal, cancellationToken);
    }
}
