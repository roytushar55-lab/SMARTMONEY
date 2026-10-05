using SmartMoney.Application.Common;

namespace SmartMoney.Application.Features.Identity.Register;

public sealed class RegisterUserValidator
{
    public IReadOnlyCollection<string> Validate(
        RegisterUserCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        ValidateFullName(command.FullName, errors);
        ValidateEmail(command.Email, errors);
        ValidatePhoneNumber(command.PhoneNumber, errors);
        ValidatePassword(command.Password, errors);
        ValidateReferralCode(command.ReferralCode, errors);

        if (!command.AgeConfirmed)
        {
            errors.Add("You must confirm that you are 18 years or older.");
        }

        if (!command.TermsAccepted)
        {
            errors.Add(
                "You must accept the Terms of Service and Privacy Policy.");
        }

        if (string.IsNullOrWhiteSpace(command.ConsentVersion))
        {
            errors.Add("Consent version is required.");
        }
        else if (!ConsentPolicy.IsAccepted(command.ConsentVersion))
        {
            errors.Add("Consent version is not recognised. Please update the app.");
        }

        return errors;
    }

    private static void ValidateFullName(
        string fullName,
        ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(fullName))
        {
            errors.Add("Full name is required.");
            return;
        }

        if (fullName.Trim().Length < 2)
        {
            errors.Add(
                "Full name must contain at least 2 characters.");
        }

        if (fullName.Trim().Length > 100)
        {
            errors.Add(
                "Full name must not exceed 100 characters.");
        }
    }

    private static void ValidateEmail(
        string email,
        ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            errors.Add("Email is required.");
            return;
        }

        if (email.Trim().Length > 254)
        {
            errors.Add(
                "Email must not exceed 254 characters.");

            return;
        }

        try
        {
            var address = new System.Net.Mail.MailAddress(
                email.Trim());

            if (!string.Equals(
                    address.Address,
                    email.Trim(),
                    StringComparison.OrdinalIgnoreCase))
            {
                errors.Add("Email format is invalid.");
            }
        }
        catch (FormatException)
        {
            errors.Add("Email format is invalid.");
        }
    }

    private static void ValidatePhoneNumber(
        string phoneNumber,
        ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(phoneNumber))
        {
            errors.Add("Phone number is required.");
            return;
        }

        string normalizedPhoneNumber = phoneNumber
            .Trim()
            .Replace(" ", string.Empty)
            .Replace("-", string.Empty);

        if (normalizedPhoneNumber.StartsWith("+"))
        {
            normalizedPhoneNumber =
                normalizedPhoneNumber[1..];
        }

        if (!normalizedPhoneNumber.All(char.IsDigit))
        {
            errors.Add(
                "Phone number must contain only digits.");

            return;
        }

        if (normalizedPhoneNumber.Length < 10 ||
            normalizedPhoneNumber.Length > 15)
        {
            errors.Add(
                "Phone number must contain between 10 and 15 digits.");
        }
    }

    private static void ValidatePassword(
        string password,
        ICollection<string> errors)
    {
        PasswordPolicy.Validate(password, errors);
    }

    private static void ValidateReferralCode(
        string? referralCode,
        ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(referralCode))
        {
            return;
        }

        if (referralCode.Trim().Length > 50)
        {
            errors.Add(
                "Referral code must not exceed 50 characters.");
        }
    }
}