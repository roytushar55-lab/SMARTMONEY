using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.UpdateCashbackSettings;

/// <summary>
/// Admin tuning of the business's cashback policy: what share of commission
/// the user receives, and how many days a cashback stays Pending before it's
/// expected to be confirmed. Null response = settings row was never seeded.
/// </summary>
public sealed class UpdateCashbackSettingsCommandHandler
    : ICommandHandler<UpdateCashbackSettingsCommand, CashbackSettingsResponse?>
{
    private readonly ICashbackSettingsRepository _settingsRepository;
    private readonly UpdateCashbackSettingsValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateCashbackSettingsCommandHandler(
        ICashbackSettingsRepository settingsRepository,
        UpdateCashbackSettingsValidator validator,
        IUnitOfWork unitOfWork)
    {
        _settingsRepository = settingsRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<CashbackSettingsResponse?> HandleAsync(
        UpdateCashbackSettingsCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var settings = await _settingsRepository.GetTrackedAsync(cancellationToken);

        if (settings is null)
        {
            return null;
        }

        settings.UserSharePercent = command.UserSharePercent;
        settings.ConfirmationWindowDays = command.ConfirmationWindowDays;
        settings.UpdatedAt = DateTime.UtcNow;

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new CashbackSettingsResponse
        {
            UserSharePercent = settings.UserSharePercent,
            ConfirmationWindowDays = settings.ConfirmationWindowDays,
            UpdatedAt = settings.UpdatedAt
        };
    }
}
