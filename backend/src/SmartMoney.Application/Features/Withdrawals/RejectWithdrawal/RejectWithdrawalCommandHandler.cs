using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.RejectWithdrawal;

/// <summary>
/// Admin decision: decline a withdrawal that has not been sent to the
/// provider. The held money returns to the user's available balance and the
/// reason is shown to them. With an automatic provider this is refused once a
/// submission has started, because the provider may still pay.
/// </summary>
public sealed class RejectWithdrawalCommandHandler
    : ICommandHandler<RejectWithdrawalCommand, WithdrawalDecisionResponse?>
{
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IPayoutProvider _provider;
    private readonly PayoutPolicy _policy;
    private readonly WithdrawalSettlement _settlement;
    private readonly IUnitOfWork _unitOfWork;

    public RejectWithdrawalCommandHandler(
        IWithdrawalRepository withdrawalRepository,
        IWalletRepository walletRepository,
        IPayoutProvider provider,
        PayoutPolicy policy,
        WithdrawalSettlement settlement,
        IUnitOfWork unitOfWork)
    {
        _provider = provider;
        _policy = policy;
        _withdrawalRepository = withdrawalRepository;
        _walletRepository = walletRepository;
        _settlement = settlement;
        _unitOfWork = unitOfWork;
    }

    public async Task<WithdrawalDecisionResponse?> HandleAsync(
        RejectWithdrawalCommand command,
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

        WithdrawalAdminSupport.EnsureRejectAllowed(
            _provider, withdrawal, _policy.MaxSubmissionAttempts);

        await _settlement.RejectAsync(
            withdrawal, command.ReviewerId, command.Reason, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return await WithdrawalDecisions.BuildAsync(
            _walletRepository, withdrawal, cancellationToken);
    }
}
