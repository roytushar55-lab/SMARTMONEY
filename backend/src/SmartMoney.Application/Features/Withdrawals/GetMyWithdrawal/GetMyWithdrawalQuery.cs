using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.GetMyWithdrawal;

/// <summary>Null result means the withdrawal does not exist or is not the user's.</summary>
public sealed class GetMyWithdrawalQuery : IQuery<WithdrawalResponse?>
{
    public Guid UserId { get; }

    public Guid WithdrawalId { get; }

    public GetMyWithdrawalQuery(Guid userId, Guid withdrawalId)
    {
        UserId = userId;
        WithdrawalId = withdrawalId;
    }
}
