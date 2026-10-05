using SmartMoney.Application.Common;

namespace SmartMoney.Application.Features.Identity.ResetPassword;

public sealed class ResetPasswordValidator
{
    public IReadOnlyCollection<string> Validate(ResetPasswordCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        ValidateEmail(command.Email, errors);
        ValidateOtp(command.Otp, errors);
        ValidatePassword(command.NewPassword, errors);

        return errors;
    }

    private static void ValidateEmail(string email, ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            errors.Add("Email is required.");
            return;
        }

        string normalizedEmail = email.Trim();

        try
        {
            var address = new System.Net.Mail.MailAddress(normalizedEmail);

            if (!string.Equals(
                    address.Address,
                    normalizedEmail,
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

    private static void ValidateOtp(string otp, ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(otp))
        {
            errors.Add("OTP is required.");
        }
    }

    private static void ValidatePassword(
        string password,
        ICollection<string> errors)
    {
        PasswordPolicy.Validate(password, errors);
    }
}
