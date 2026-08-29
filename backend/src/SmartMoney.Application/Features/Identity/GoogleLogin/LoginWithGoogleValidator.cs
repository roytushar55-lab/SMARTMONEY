namespace SmartMoney.Application.Features.Identity.GoogleLogin;

public sealed class LoginWithGoogleValidator
{
    public IReadOnlyCollection<string> Validate(
        LoginWithGoogleCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(command.IdToken))
        {
            errors.Add("A Google id token is required.");
        }

        return errors;
    }
}
