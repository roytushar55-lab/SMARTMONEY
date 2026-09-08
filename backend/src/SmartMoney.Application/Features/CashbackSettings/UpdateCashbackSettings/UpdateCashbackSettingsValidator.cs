namespace SmartMoney.Application.Features.CashbackSettings.UpdateCashbackSettings;

public sealed class UpdateCashbackSettingsValidator
{
    public IReadOnlyCollection<string> Validate(UpdateCashbackSettingsCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (command.UserSharePercent <= 0 || command.UserSharePercent > 100)
        {
            errors.Add("User share percent must be between 0 and 100.");
        }

        if (command.ConfirmationWindowDays <= 0)
        {
            errors.Add("Confirmation window days must be greater than zero.");
        }

        return errors;
    }
}
