using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawal;

/// <summary>Null result means the withdrawal was not found.</summary>
public sealed class GetAdminWithdrawalQuery : IQuery<AdminWithdrawalResponse?>
{
    public Guid WithdrawalId { get; }

    public GetAdminWithdrawalQuery(Guid withdrawalId)
    {
        WithdrawalId = withdrawalId;
    }
}
