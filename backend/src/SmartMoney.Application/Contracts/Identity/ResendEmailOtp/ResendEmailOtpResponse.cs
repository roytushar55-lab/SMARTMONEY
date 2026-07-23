namespace SmartMoney.Application.Contracts.Identity.ResendEmailOtp;

public sealed class ResendEmailOtpResponse
{
    public string Email { get; set; } = string.Empty;

    public DateTime ExpiresAt { get; set; }

    public string Message { get; set; } = string.Empty;
}