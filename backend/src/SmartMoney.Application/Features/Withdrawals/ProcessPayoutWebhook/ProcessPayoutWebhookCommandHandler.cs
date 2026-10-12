using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.ProcessPayoutWebhook;

/// <summary>
/// Applies a payout provider's callback. The provider itself verifies the
/// signature (it alone knows its scheme); nothing is trusted until it returns
/// an event. Safe against retries and out-of-order delivery because the
/// settlement is idempotent.
/// </summary>
public sealed class ProcessPayoutWebhookCommandHandler
    : ICommandHandler<ProcessPayoutWebhookCommand, PayoutWebhookResult>
{
    private readonly IPayoutProvider _provider;
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly WithdrawalSettlement _settlement;
    private readonly IUnitOfWork _unitOfWork;

    public ProcessPayoutWebhookCommandHandler(
        IPayoutProvider provider,
        IWithdrawalRepository withdrawalRepository,
        WithdrawalSettlement settlement,
        IUnitOfWork unitOfWork)
    {
        _provider = provider;
        _withdrawalRepository = withdrawalRepository;
        _settlement = settlement;
        _unitOfWork = unitOfWork;
    }

    public async Task<PayoutWebhookResult> HandleAsync(
        ProcessPayoutWebhookCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);

        // Only the configured provider has any business calling us.
        if (!string.Equals(
                command.ProviderName, _provider.Name, StringComparison.OrdinalIgnoreCase))
        {
            return PayoutWebhookResult.UnknownProvider;
        }

        PayoutWebhookEvent? webhookEvent = await _provider.ParseWebhookAsync(
            new PayoutWebhookRequest(command.Headers, command.Body),            cancellationToken);

        if (webhookEvent is null || string.IsNullOrWhiteSpace(webhookEvent.Reference))
        {
            return PayoutWebhookResult.Invalid;
        }

        Withdrawal? withdrawal = await _withdrawalRepository.GetByReferenceAsync(
            webhookEvent.Reference.Trim(), cancellationToken);

        if (withdrawal is null && !string.IsNullOrWhiteSpace(webhookEvent.ProviderReference))
        {
            withdrawal = await _withdrawalRepository.GetByProviderReferenceAsync(
                _provider.Name, webhookEvent.ProviderReference.Trim(), cancellationToken);
        }

        if (withdrawal is null)
        {
            // Genuine but not ours (or already purged). Acknowledge so the
            // provider stops retrying something we cannot act on.
            return PayoutWebhookResult.Ignored;
        }

        SettlementOutcome outcome = await _settlement.ApplyProviderStateAsync(
            withdrawal,
            webhookEvent.State,
            webhookEvent.ProviderReference,
            webhookEvent.Message,
            webhookEvent.ActualFee,
            cancellationToken);

        if (outcome is SettlementOutcome.Applied or SettlementOutcome.NeedsAttention)
        {
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }

        return outcome switch
        {
            SettlementOutcome.Applied => PayoutWebhookResult.Applied,
            SettlementOutcome.Duplicate => PayoutWebhookResult.Duplicate,
            SettlementOutcome.NeedsAttention => PayoutWebhookResult.NeedsAttention,
            _ => PayoutWebhookResult.Ignored
        };
    }
}
