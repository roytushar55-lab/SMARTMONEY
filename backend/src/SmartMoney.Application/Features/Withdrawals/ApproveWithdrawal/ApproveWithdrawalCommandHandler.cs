using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.ApproveWithdrawal;

/// <summary>
/// Admin decision: clear a requested withdrawal for payout. With an
/// automatic provider the payout is submitted straight away; with the manual
/// provider the admin pays outside the system and then records it (mark paid).
/// </summary>
public sealed class ApproveWithdrawalCommandHandler
    : ICommandHandler<ApproveWithdrawalCommand, WithdrawalDecisionResponse?>
{
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IWithdrawalProcessor _processor;
    private readonly IUnitOfWork _unitOfWork;

    public ApproveWithdrawalCommandHandler(
        IWithdrawalRepository withdrawalRepository,
        IWalletRepository walletRepository,
        IWithdrawalProcessor processor,
        IUnitOfWork unitOfWork)
    {
        _withdrawalRepository = withdrawalRepository;
        _walletRepository = walletRepository;
        _processor = processor;
        _unitOfWork = unitOfWork;
    }

    public async Task<WithdrawalDecisionResponse?> HandleAsync(
        ApproveWithdrawalCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        Withdrawal? withdrawal = await _withdrawalRepository.GetByIdAsync(
            command.WithdrawalId, cancellationToken);

        if (withdrawal is null)
        {
            return null;
        }

        withdrawal.Approve(command.ReviewerId);

        // The approval is saved on its own first: it must be durable before
        // the provider is contacted.
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        try
        {
            await _processor.SubmitAsync(withdrawal.Id, cancellationToken);
        }
        catch (ConcurrencyConflictException)
        {
            // A webhook or the worker settled it first; theirs stands.
        }

        return await WithdrawalDecisions.BuildAsync(
            _walletRepository, withdrawal, cancellationToken);
    }
}
