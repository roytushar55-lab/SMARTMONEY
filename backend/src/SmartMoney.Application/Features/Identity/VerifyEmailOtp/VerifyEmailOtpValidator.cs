namespace SmartMoney.Application.Features.Identity.VerifyEmailOtp;

public sealed class VerifyEmailOtpValidator
{
    public IReadOnlyCollection<string> Validate(
        VerifyEmailOtpCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        ValidateEmail(command.Email, errors);
        ValidateOtp(command.Otp, errors);

        return errors;
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

        try
        {
            var address =
                new System.Net.Mail.MailAddress(email.Trim());

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

    private static void ValidateOtp(
        string otp,
        ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(otp))
        {
            errors.Add("OTP is required.");
            return;
        }

        string normalizedOtp = otp.Trim();

        if (normalizedOtp.Length != 6)
        {
            errors.Add("OTP must contain exactly 6 digits.");
            return;
        }

        if (!normalizedOtp.All(char.IsDigit))
        {
            errors.Add("OTP must contain only digits.");
        }
    }
}