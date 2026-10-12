using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;

namespace SmartMoney.Application.Features.Withdrawals.GetMyWithdrawal;

public sealed class GetMyWithdrawalQueryHandler
    : IQueryHandler<GetMyWithdrawalQuery, WithdrawalResponse?>
{
    private readonly IWithdrawalRepository _withdrawalRepository;

    public GetMyWithdrawalQueryHandler(IWithdrawalRepository withdrawalRepository)
    {
        _withdrawalRepository = withdrawalRepository;
    }

    public async Task<WithdrawalResponse?> HandleAsync(
        GetMyWithdrawalQuery query,
        CancellationToken cancellationToken)
    {
        var withdrawal = await _withdrawalRepository.GetByIdAsync(
            query.WithdrawalId, cancellationToken);

        return withdrawal is null || withdrawal.UserId != query.UserId
            ? null
            : WithdrawalResponse.FromEntity(withdrawal);
    }
}
