using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.ResendEmailOtp;

namespace SmartMoney.Application.Features.Identity.ResendEmailOtp;

public sealed class ResendEmailOtpCommand
    : ICommand<ResendEmailOtpResponse>
{
    public string Email { get; }

    public ResendEmailOtpCommand(string email)
    {
        Email = email;
    }
}