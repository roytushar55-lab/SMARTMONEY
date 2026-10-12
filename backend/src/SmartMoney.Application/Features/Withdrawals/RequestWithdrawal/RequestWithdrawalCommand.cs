using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.RequestWithdrawal;

public sealed class RequestWithdrawalCommand : ICommand<WithdrawalResponse>
{
    public Guid UserId { get; }

    public RequestWithdrawalRequest Request { get; }

    public RequestWithdrawalCommand(Guid userId, RequestWithdrawalRequest request)
    {
        UserId = userId;
        Request = request;
    }
}
