namespace SmartMoney.Application.Contracts.Identity.VerifyEmailOtp;

public sealed class VerifyEmailOtpResponse
{
    public Guid UserId { get; set; }

    public string Email { get; set; } = string.Empty;

    public bool IsEmailVerified { get; set; }

    public string Status { get; set; } = string.Empty;
}