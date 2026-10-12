using SmartMoney.Application.Abstractions.Authentication;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Withdrawals.RequestWithdrawal;

/// <summary>
/// A user asks to move wallet money out. The amount is moved from available
/// to held right away (so it cannot be spent twice) and stays held until the
/// withdrawal is paid, fails, is declined or is cancelled. The destination is
/// stored encrypted. When admin approval is switched off the withdrawal is
/// approved on the spot and, with an automatic provider, sent right away.
/// </summary>
public sealed class RequestWithdrawalCommandHandler
    : ICommandHandler<RequestWithdrawalCommand, WithdrawalResponse>
{
    private readonly IUserRepository _userRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IWalletTransactionRepository _walletTransactionRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IPayoutDestinationProtector _protector;
    private readonly PayoutPolicy _policy;
    private readonly IWithdrawalProcessor _processor;
    private readonly IUnitOfWork _unitOfWork;

    public RequestWithdrawalCommandHandler(
        IUserRepository userRepository,
        IWalletRepository walletRepository,
        IWithdrawalRepository withdrawalRepository,
        IWalletTransactionRepository walletTransactionRepository,
        IPasswordHasher passwordHasher,
        IPayoutDestinationProtector protector,
        PayoutPolicy policy,
        IWithdrawalProcessor processor,
        IUnitOfWork unitOfWork)
    {
        _processor = processor;
        _userRepository = userRepository;
        _walletRepository = walletRepository;
        _withdrawalRepository = withdrawalRepository;
        _walletTransactionRepository = walletTransactionRepository;
        _passwordHasher = passwordHasher;
        _protector = protector;
        _policy = policy;
        _unitOfWork = unitOfWork;
    }

    public async Task<WithdrawalResponse> HandleAsync(
        RequestWithdrawalCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);
        ArgumentNullException.ThrowIfNull(command.Request);

        RequestWithdrawalRequest request = command.Request;

        PayoutDestination destination = WithdrawalRules.BuildDestination(
            request.Method,
            request.BeneficiaryName,
            request.UpiId,
            request.BankAccountNumber,
            request.IfscCode);

        if (string.IsNullOrWhiteSpace(request.Password))
        {
            throw new ArgumentException("Password is required.");
        }

        User user = await _userRepository.GetByIdAsync(
                command.UserId, cancellationToken)
            ?? throw new KeyNotFoundException("Account was not found.");

        // Re-authenticate before money moves, so a stolen session alone
        // cannot drain the wallet. Checked before anything about the
        // balance is revealed.
        if (user.PasswordHash is null ||
            !_passwordHasher.Verify(request.Password, user.PasswordHash))
        {
            throw new ArgumentException("Incorrect password.");
        }

        Wallet? wallet = await _walletRepository.GetByUserIdAsync(
            user.Id, cancellationToken);

        int open = await _withdrawalRepository.CountOpenByUserIdAsync(
            user.Id, cancellationToken);

        WithdrawalBlock? block = WithdrawalRules.CheckEligibility(
            _policy, user, wallet, open, request.Amount);

        if (block is not null)
        {
            throw block.IsConflict
                ? new InvalidOperationException(block.Message)
                : new ArgumentException(block.Message);
        }

        PayoutQuote quote = _policy.Quote(request.Amount);

        var withdrawal = new Withdrawal(
            user.Id,
            wallet!.Id,
            Withdrawal.NewReference(),
            quote.Amount,
            quote.FeeTotal,
            quote.UserFee,
            destination.Method,
            destination.Mask(),
            _protector.Protect(destination));

        // Wallet first, then the ledger entry from its new balances.
        wallet.HoldForWithdrawal(withdrawal.Amount);

        await _withdrawalRepository.AddAsync(withdrawal, cancellationToken);

        await _walletTransactionRepository.AddAsync(
            new WalletTransaction(
                wallet.Id,
                user.Id,
                WalletTransactionType.WithdrawalRequested,
                withdrawal.Amount,
                cashbackId: null,
                $"Withdrawal {withdrawal.Reference} requested.",
                wallet.AvailableBalance,
                wallet.PendingBalance,
                wallet.HeldBalance,
                withdrawal.Id),
            cancellationToken);

        if (!_policy.RequireAdminApproval)
        {
            withdrawal.Approve(reviewerId: null);
        }

        // The wallet carries a concurrency token, so two simultaneous
        // requests cannot both hold the same money: the second save fails
        // with a conflict (HTTP 409).
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        if (withdrawal.Status == WithdrawalStatus.Approved)
        {
            // Saved above first: the request must be durable before the
            // provider is contacted. A failure here is retried by the worker.
            try
            {
                await _processor.SubmitAsync(withdrawal.Id, cancellationToken);
            }
            catch (ConcurrencyConflictException)
            {
                // A webhook settled it first; theirs stands.
            }
        }

        return WithdrawalResponse.FromEntity(withdrawal);
    }
}
