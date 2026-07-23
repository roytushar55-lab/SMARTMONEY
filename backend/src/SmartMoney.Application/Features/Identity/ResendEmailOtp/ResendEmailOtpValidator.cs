namespace SmartMoney.Application.Features.Identity.ResendEmailOtp;

public sealed class ResendEmailOtpValidator
{
    public IReadOnlyCollection<string> Validate(
        ResendEmailOtpCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        ValidateEmail(command.Email, errors);

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

        string normalizedEmail = email.Trim();

        try
        {
            var address =
                new System.Net.Mail.MailAddress(normalizedEmail);

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
}