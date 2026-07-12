using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.Register;

namespace SmartMoney.Application.Features.Identity.Register;

public sealed class RegisterUserCommand : ICommand<RegisterUserResponse>
{
    public string FullName { get; }

    public string Email { get; }

    public string PhoneNumber { get; }

    public string Password { get; }

    public string? ReferralCode { get; }

    public RegisterUserCommand(
        string fullName,
        string email,
        string phoneNumber,
        string password,
        string? referralCode)
    {
        FullName = fullName;
        Email = email;
        PhoneNumber = phoneNumber;
        Password = password;
        ReferralCode = referralCode;
    }
}