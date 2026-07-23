using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.VerifyEmailOtp;

namespace SmartMoney.Application.Features.Identity.VerifyEmailOtp;

public sealed class VerifyEmailOtpCommand
    : ICommand<VerifyEmailOtpResponse>
{
    public string Email { get; }

    public string Otp { get; }

    public VerifyEmailOtpCommand(
        string email,
        string otp)
    {
        Email = email;
        Otp = otp;
    }
}