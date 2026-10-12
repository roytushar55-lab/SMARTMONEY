using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.PreviewWithdrawal;

public sealed class PreviewWithdrawalQuery : IQuery<WithdrawalPreviewResponse>
{
    public Guid UserId { get; }

    public decimal Amount { get; }

    public PreviewWithdrawalQuery(Guid userId, decimal amount)
    {
        UserId = userId;
        Amount = amount;
    }
}
