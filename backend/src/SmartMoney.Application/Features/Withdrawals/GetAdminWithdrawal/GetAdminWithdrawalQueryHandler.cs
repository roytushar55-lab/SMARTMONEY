using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawal;

/// <summary>
/// One withdrawal for the admin. The full bank or UPI details are decrypted
/// only while the withdrawal is open (an admin needs them to pay it); once
/// it settles they are gone for good.
/// </summary>
public sealed class GetAdminWithdrawalQueryHandler
    : IQueryHandler<GetAdminWithdrawalQuery, AdminWithdrawalResponse?>
{
    private readonly IWithdrawalRepository _withdrawalRepository;
    private readonly IPayoutDestinationProtector _protector;

    public GetAdminWithdrawalQueryHandler(
        IWithdrawalRepository withdrawalRepository,
        IPayoutDestinationProtector protector)
    {
        _withdrawalRepository = withdrawalRepository;
        _protector = protector;
    }

    public async Task<AdminWithdrawalResponse?> HandleAsync(
        GetAdminWithdrawalQuery query,
        CancellationToken cancellationToken)
    {
        Withdrawal? withdrawal = await _withdrawalRepository.GetWithUserByIdAsync(
            query.WithdrawalId, cancellationToken);

        if (withdrawal is null)
        {
            return null;
        }

        AdminWithdrawalResponse response = AdminWithdrawalResponse.FromEntity(withdrawal);

        if (withdrawal.IsOpen && !string.IsNullOrEmpty(withdrawal.DestinationProtected))
        {
            try
            {
                PayoutDestination destination =
                    _protector.Unprotect(withdrawal.DestinationProtected);

                response.Destination = new AdminWithdrawalDestination
                {
                    Method = destination.Method.ToString(),
                    BeneficiaryName = destination.BeneficiaryName,
                    UpiId = destination.UpiId,
                    BankAccountNumber = destination.BankAccountNumber,
                    IfscCode = destination.IfscCode
                };
            }
            catch (Exception)
            {
                response.DestinationUnreadable = true;
            }
        }

        return response;
    }
}
