namespace SmartMoney.Application.Features.Identity.Login;

public sealed class LoginUserValidator
{
    public IReadOnlyCollection<string> Validate(
        LoginUserCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        ValidateEmail(command.Email, errors);
        ValidatePassword(command.Password, errors);

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

    private static void ValidatePassword(
        string password,
        ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(password))
        {
            errors.Add("Password is required.");
        }
    }
}