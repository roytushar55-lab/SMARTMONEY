namespace SmartMoney.Application.Contracts.Identity.Register;

public sealed class RegisterUserResponse
{
    public Guid UserId { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string PhoneNumber { get; set; } = string.Empty;

    public string ReferralCode { get; set; } = string.Empty;

    public bool IsEmailVerified { get; set; }

    public bool IsPhoneVerified { get; set; }
}