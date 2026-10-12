using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals;

/// <summary>
/// Sends approved withdrawals to the payout provider. Only does anything
/// when the active provider pays by API; with the manual provider an admin
/// pays outside the system and records it instead.
/// </summary>
public interface IWithdrawalProcessor
{
    /// <summary>
    /// Submits one Approved withdrawal. Safe to call repeatedly and for any
    /// withdrawal: anything that is not Approved, or that has used up its
    /// retries, is left alone.
    /// </summary>
    Task SubmitAsync(Guid withdrawalId, CancellationToken cancellationToken);

    /// <summary>
    /// Asks the provider where a Processing payout stands (for when no
    /// webhook arrived) and applies the answer. Safe to call repeatedly and
    /// for any withdrawal; anything not Processing is left alone.
    /// </summary>
    Task ReconcileAsync(Guid withdrawalId, CancellationToken cancellationToken);

    /// <summary>
    /// The work the background worker should do now. Empty when the active
    /// provider is not automatic. Only ids are returned: each item must be
    /// processed in its own scope, so one failed save cannot poison the next.
    /// </summary>
    Task<WithdrawalWorkList> ListPendingAsync(CancellationToken cancellationToken);
}

/// <summary>Withdrawals waiting for submission, and ones whose result is overdue.</summary>
public sealed record WithdrawalWorkList(
    IReadOnlyList<Guid> ToSubmit,
    IReadOnlyList<Guid> ToReconcile)
{
    public static readonly WithdrawalWorkList Empty = new(
        Array.Empty<Guid>(), Array.Empty<Guid>());
}

public sealed class WithdrawalProcessor : IWithdrawalProcessor
{
    private const string Currency = "INR";

    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IPayoutProvider _provider;
    private readonly IPayoutDestinationProtector _protector;
    private readonly WithdrawalSettlement _settlement;
    private readonly PayoutPolicy _policy;
    private readonly IUnitOfWork _unitOfWork;

    public WithdrawalProcessor(
        IWithdrawalRepository withdrawalRepository,
        IPayoutProvider provider,
        IPayoutDestinationProtector protector,
        WithdrawalSettlement settlement,
        PayoutPolicy policy,
        IUnitOfWork unitOfWork)
    {
        _withdrawalRepository = withdrawalRepository;
        _provider = provider;
        _protector = protector;
        _settlement = settlement;
        _policy = policy;
        _unitOfWork = unitOfWork;
    }

    public async Task SubmitAsync(
        Guid withdrawalId,
        CancellationToken cancellationToken)
    {
        if (!_provider.SupportsAutomaticPayout)
        {
            return;
        }

        Withdrawal? withdrawal = await _withdrawalRepository.GetByIdAsync(
            withdrawalId, cancellationToken);

        // A flagged withdrawal is waiting for a person (its details cannot be
        // read, or its retries are used up). Trying again would only repeat the
        // failure; once an admin acknowledges the flag it is eligible again.
        if (withdrawal is null ||
            withdrawal.Status != WithdrawalStatus.Approved ||
            withdrawal.NeedsAttention ||
            withdrawal.SubmissionAttempts >= _policy.MaxSubmissionAttempts)
        {
            return;
        }

        PayoutDestination destination;

        try
        {
            destination = _protector.Unprotect(
                withdrawal.DestinationProtected ?? string.Empty);
        }
        catch (Exception)
        {
            // Retrying cannot fix a lost key or a corrupt value.
            withdrawal.RecordSubmissionFailure(
                _provider.Name, "The stored payout destination could not be read.");
            withdrawal.FlagNeedsAttention(
                "Stored destination is unreadable; pay manually or reject.");
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            return;
        }

        var instruction = new PayoutInstruction(
            withdrawal.Reference,
            withdrawal.NetAmount,
            Currency,
            destination,
            $"SmartMoney withdrawal {withdrawal.Reference}");

        // Save that we are about to send BEFORE sending. If an admin rejected
        // the withdrawal in the meantime this save loses the concurrency
        // check and nothing is sent; if it wins, the row now counts as sent
        // and a reject is refused (see WithdrawalAdminSupport), so the money
        // can never be both paid out and refunded. A conflict here propagates
        // on purpose: no money has moved yet.
        withdrawal.BeginSubmission(_provider.Name);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        PayoutSubmissionResult result;

        try
        {
            // The reference is the provider's idempotency key, so if the
            // call succeeded but our save below fails, the retry cannot pay twice.
            result = await _provider.SubmitAsync(instruction, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            result = PayoutSubmissionResult.TemporaryFailure(
                $"{exception.GetType().Name}: {exception.Message}");
        }

        switch (result.Outcome)
        {
            case PayoutSubmissionOutcome.Accepted:
                withdrawal.MarkSubmitted(_provider.Name, result.ProviderReference);
                break;

            case PayoutSubmissionOutcome.Completed:
                withdrawal.MarkSubmitted(_provider.Name, result.ProviderReference);
                await _settlement.CompleteAsync(
                    withdrawal,
                    result.ProviderReference,
                    result.ActualFee,
                    cancellationToken);
                break;

            case PayoutSubmissionOutcome.Rejected:
                await _settlement.FailAsync(
                    withdrawal,
                    WithdrawalSettlement.DefaultFailureReason,
                    result.Message,
                    cancellationToken);
                break;

            default:
                withdrawal.RecordSubmissionFailure(
                    _provider.Name, result.Message ?? "Temporary provider failure.");

                if (withdrawal.SubmissionAttempts >= _policy.MaxSubmissionAttempts)
                {
                    withdrawal.FlagNeedsAttention(
                        "Automatic retries are used up; pay manually or reject.");
                }

                break;
        }

        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task ReconcileAsync(
        Guid withdrawalId,
        CancellationToken cancellationToken)
    {
        if (!_provider.SupportsAutomaticPayout)
        {
            return;
        }

        Withdrawal? withdrawal = await _withdrawalRepository.GetByIdAsync(
            withdrawalId, cancellationToken);

        if (withdrawal is null || withdrawal.Status != WithdrawalStatus.Processing)
        {
            return;
        }

        PayoutStatusResult status;

        try
        {
            status = await _provider.GetStatusAsync(
                withdrawal.Reference, withdrawal.ProviderReference, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // Provider unreachable: note it, move the "last checked" time
            // forward, and try again on a later pass.
            withdrawal.RecordStatusCheck(
                $"{exception.GetType().Name}: {exception.Message}");
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            return;
        }

        SettlementOutcome outcome = await _settlement.ApplyProviderStateAsync(
            withdrawal,
            status.State,
            status.ProviderReference,
            status.Message,
            status.ActualFee,
            cancellationToken);

        if (outcome == SettlementOutcome.Ignored)
        {
            if (status.State == PayoutState.Unknown && !withdrawal.NeedsAttention)
            {
                withdrawal.FlagNeedsAttention(
                    "The provider does not recognise this payout. Check it there.");
            }
            else
            {
                withdrawal.RecordStatusCheck();
            }
        }

        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task<WithdrawalWorkList> ListPendingAsync(
        CancellationToken cancellationToken)
    {
        if (!_provider.SupportsAutomaticPayout)
        {
            return WithdrawalWorkList.Empty;
        }

        DateTime now = DateTime.UtcNow;

        // A just-approved withdrawal is submitted inline by the request that
        // approved it; the worker only picks up what that missed or retries.
        // Flagged ones are waiting for a person (unreadable details, retries
        // used up), so retrying them would only repeat the same failure.
        var submit = await _withdrawalRepository.ListIdsByStatusAsync(
            WithdrawalStatus.Approved,
            now - _policy.WorkerInterval,
            _policy.WorkerBatchSize,
            submissionAttemptsBelow: _policy.MaxSubmissionAttempts,
            needsAttention: false,
            cancellationToken: cancellationToken);

        // Flagged payouts in flight are still worth asking the provider about:
        // the answer may well resolve them.
        var reconcile = await _withdrawalRepository.ListIdsByStatusAsync(
            WithdrawalStatus.Processing,
            now - _policy.ReconcileAfter,
            _policy.WorkerBatchSize,
            cancellationToken: cancellationToken);

        return new WithdrawalWorkList(submit, reconcile);
    }
}
