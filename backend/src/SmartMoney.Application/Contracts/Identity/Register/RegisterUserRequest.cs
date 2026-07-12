namespace SmartMoney.Application.Contracts.Identity.Register;

public sealed class RegisterUserRequest
{
    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string PhoneNumber { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public string? ReferralCode { get; set; }
}