using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Cashbacks;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Cashbacks.ReverseCashback;

/// <summary>
/// Admin decision: reverse a previously confirmed cashback (the domain
/// guards that history) and debit the amount back out of the wallet's
/// available balance. Fails with 409 if the user already withdrew the funds.
/// Null response = cashback not found.
/// </summary>
public sealed class ReverseCashbackCommandHandler
    : ICommandHandler<ReverseCashbackCommand, CashbackDecisionResponse?>
{
    private readonly ICashbackRepository _cashbackRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IWalletTransactionRepository _walletTransactionRepository;
    private readonly ICashbackEventRepository _eventRepository;
    private readonly IUnitOfWork _unitOfWork;

    public ReverseCashbackCommandHandler(
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
        ReverseCashbackCommand command,
        CancellationToken cancellationToken)
    {
        var cashback = await _cashbackRepository.GetByIdAsync(
            command.CashbackId, cancellationToken);

        if (cashback is null)
        {
            return null;
        }

        var statusBefore = cashback.Status;

        cashback.Reverse();

        await _eventRepository.AddAsync(
            new CashbackEvent(
                cashback.Id,
                CashbackEventType.Reversed,
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

        wallet.ReverseConfirmedCashback(cashback.CashbackAmount);

        await _walletTransactionRepository.AddAsync(
            new WalletTransaction(
                wallet.Id,
                cashback.UserId,
                WalletTransactionType.CashbackReversed,
                cashback.CashbackAmount,
                cashback.Id,
                "Cashback reversed by admin.",
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
