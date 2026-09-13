namespace SmartMoney.Application.Features.CashbackSettings.CreateCashbackOverride;

public sealed class CreateCashbackOverrideValidator
{
    public IReadOnlyCollection<string> Validate(CreateCashbackOverrideCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (command.StoreId == Guid.Empty)
        {
            errors.Add("Store is required.");
        }

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
