namespace SmartMoney.Application.Contracts.Identity.VerifyEmailOtp;

public sealed class VerifyEmailOtpRequest
{
    public string Email { get; set; } = string.Empty;

    public string Otp { get; set; } = string.Empty;
}