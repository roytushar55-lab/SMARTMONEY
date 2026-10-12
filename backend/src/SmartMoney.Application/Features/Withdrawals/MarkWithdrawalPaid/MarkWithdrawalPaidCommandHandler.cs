using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals.MarkWithdrawalPaid;

/// <summary>
/// Admin records that they paid the user outside the system (the manual
/// provider's flow). The held money becomes withdrawn and the bank reference
/// is kept. A still-requested withdrawal is approved first, so one click
/// covers "approve and I have paid it".
/// </summary>
public sealed class MarkWithdrawalPaidCommandHandler
    : ICommandHandler<MarkWithdrawalPaidCommand, WithdrawalDecisionResponse?>
{
    private const int MaxReferenceLength = 100;

    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IPayoutProvider _provider;
    private readonly PayoutPolicy _policy;
    private readonly WithdrawalSettlement _settlement;
    private readonly IUnitOfWork _unitOfWork;

    public MarkWithdrawalPaidCommandHandler(
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
        MarkWithdrawalPaidCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        string reference = (command.TransactionReference ?? string.Empty).Trim();

        if (reference.Length == 0)
        {
            throw new ArgumentException("The bank transaction reference is required.");
        }

        if (reference.Length > MaxReferenceLength)
        {
            throw new ArgumentException(
                $"The transaction reference can be at most {MaxReferenceLength} characters.");
        }

        Withdrawal? withdrawal = await _withdrawalRepository.GetByIdAsync(
            command.WithdrawalId, cancellationToken);

        if (withdrawal is null)
        {
            return null;
        }

        WithdrawalAdminSupport.EnsureManualSettlementAllowed(
            _provider, withdrawal, _policy.MaxSubmissionAttempts);

        if (withdrawal.Status == WithdrawalStatus.Requested)
        {
            withdrawal.Approve(command.ReviewerId);
        }

        await _settlement.CompleteAsync(withdrawal, reference, null, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return await WithdrawalDecisions.BuildAsync(
            _walletRepository, withdrawal, cancellationToken);
    }
}
