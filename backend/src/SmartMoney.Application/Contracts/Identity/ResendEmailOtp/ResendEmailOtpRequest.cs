namespace SmartMoney.Application.Contracts.Identity.ResendEmailOtp;

public sealed class ResendEmailOtpRequest
{
    public string Email { get; set; } = string.Empty;
}