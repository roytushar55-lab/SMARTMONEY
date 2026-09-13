using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.CashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.GetCashbackSettings;

/// <summary>Null response = the settings row was never seeded (should not happen post-startup).</summary>
public sealed class GetCashbackSettingsQueryHandler
    : IQueryHandler<GetCashbackSettingsQuery, CashbackSettingsResponse?>
{
    private readonly ICashbackSettingsRepository _settingsRepository;

    public GetCashbackSettingsQueryHandler(ICashbackSettingsRepository settingsRepository)
    {
        _settingsRepository = settingsRepository;
    }

    public async Task<CashbackSettingsResponse?> HandleAsync(
        GetCashbackSettingsQuery query,
        CancellationToken cancellationToken)
    {
        var settings = await _settingsRepository.GetAsync(cancellationToken);

        if (settings is null)
        {
            return null;
        }

        return new CashbackSettingsResponse
        {
            UserSharePercent = settings.UserSharePercent,
            ConfirmationWindowDays = settings.ConfirmationWindowDays,
            UpdatedAt = settings.UpdatedAt
        };
    }
}
