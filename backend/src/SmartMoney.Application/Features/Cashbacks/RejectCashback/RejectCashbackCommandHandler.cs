using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Cashbacks;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Cashbacks.RejectCashback;

/// <summary>
/// Admin decision: reject a never-confirmed cashback and remove its amount
/// from the wallet's pending bucket. A previously confirmed cashback must be
/// reversed instead — its money sits in available, not pending.
/// Null response = cashback not found.
/// </summary>
public sealed class RejectCashbackCommandHandler
    : ICommandHandler<RejectCashbackCommand, CashbackDecisionResponse?>
{
    private readonly ICashbackRepository _cashbackRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IWalletTransactionRepository _walletTransactionRepository;
    private readonly ICashbackEventRepository _eventRepository;
    private readonly IUnitOfWork _unitOfWork;

    public RejectCashbackCommandHandler(
        ICashbackRepository cashbackRepository,
        IWalletRepository walletRepository,
        IWalletTransactionRepository walletTransactionRepository,
        ICashbackEventRepository eventRepository,
        IUnitOfWork unitOfWork)
    {
        _cashbackRepository = cashbackRepository;
        _walletRepository = walletRepository;
        _walletTransactionRepository = walletTransactionRepository;
        _eventRepository = eventRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<CashbackDecisionResponse?> HandleAsync(
        RejectCashbackCommand command,
        CancellationToken cancellationToken)
    {
        var cashback = await _cashbackRepository.GetByIdAsync(
            command.CashbackId, cancellationToken);

        if (cashback is null)
        {
            return null;
        }

        if (cashback.ConfirmedDate is not null)
        {
            throw new InvalidOperationException(
                "This cashback was previously confirmed; use reverse instead of reject.");
        }

        var statusBefore = cashback.Status;

        cashback.Reject();

        await _eventRepository.AddAsync(
            new CashbackEvent(
                cashback.Id,
                CashbackEventType.Rejected,
                command.ReviewerId,
                statusBefore,
                cashback.Status,
                cashback.CashbackAmount,
                cashback.AffiliateConversion?.NetworkStatus,
                command.Reason),
            cancellationToken);

        var wallet = await _walletRepository.GetByIdAsync(
            cashback.WalletId, cancellationToken);

        if (wallet is null)
        {
            throw new InvalidOperationException(
                "Wallet for this cashback was not found.");
        }

        wallet.RemovePendingCashback(cashback.CashbackAmount);

        await _walletTransactionRepository.AddAsync(
            new WalletTransaction(
                wallet.Id,
                cashback.UserId,
                WalletTransactionType.CashbackRejected,
                cashback.CashbackAmount,
                cashback.Id,
                "Cashback rejected by admin.",
                wallet.AvailableBalance,
                wallet.PendingBalance,
                wallet.HeldBalance),
            cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new CashbackDecisionResponse
        {
            CashbackId = cashback.Id,
            Status = cashback.Status.ToString(),
            AvailableBalance = wallet.AvailableBalance,
            PendingBalance = wallet.PendingBalance
        };
    }
}
