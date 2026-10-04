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

    public bool AgeConfirmed { get; }

    public bool TermsAccepted { get; }

    public string? ConsentVersion { get; }

    public string? ConsentIpAddress { get; }

    public RegisterUserCommand(
        string fullName,
        string email,
        string phoneNumber,
        string password,
        string? referralCode,
        bool ageConfirmed,
        bool termsAccepted,
        string? consentVersion,
        string? consentIpAddress)
    {
        AgeConfirmed = ageConfirmed;
        TermsAccepted = termsAccepted;
        ConsentVersion = consentVersion;
        ConsentIpAddress = consentIpAddress;
        FullName = fullName;
        Email = email;
        PhoneNumber = phoneNumber;
        Password = password;
        ReferralCode = referralCode;
    }
}