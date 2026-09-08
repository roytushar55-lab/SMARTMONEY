using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.UpdateCashbackSettings;

public sealed class UpdateCashbackSettingsCommand : ICommand<CashbackSettingsResponse?>
{
    public decimal UserSharePercent { get; }

    public int ConfirmationWindowDays { get; }

    public UpdateCashbackSettingsCommand(decimal userSharePercent, int confirmationWindowDays)
    {
        UserSharePercent = userSharePercent;
        ConfirmationWindowDays = confirmationWindowDays;
    }
}
