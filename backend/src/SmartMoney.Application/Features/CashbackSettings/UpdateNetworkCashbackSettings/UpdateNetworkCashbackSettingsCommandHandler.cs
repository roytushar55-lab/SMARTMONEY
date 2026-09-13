using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.CashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.GetNetworkCashbackSettings;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.CashbackSettings.UpdateNetworkCashbackSettings;

/// <summary>
/// Admin tuning of one network's global cashback policy — the middle rung
/// of the hierarchy, between the system-wide fallback and per-store
/// overrides. Upserts: the first call for a network creates its row, later
/// calls update it in place. Null response = the network id does not exist.
/// </summary>
public sealed class UpdateNetworkCashbackSettingsCommandHandler
    : ICommandHandler<UpdateNetworkCashbackSettingsCommand, NetworkCashbackSettingsResponse?>
{
    private readonly IAffiliateNetworkRepository _networkRepository;
    private readonly INetworkCashbackSettingsRepository _settingsRepository;
    private readonly UpdateNetworkCashbackSettingsValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateNetworkCashbackSettingsCommandHandler(
        IAffiliateNetworkRepository networkRepository,
        INetworkCashbackSettingsRepository settingsRepository,
        UpdateNetworkCashbackSettingsValidator validator,
        IUnitOfWork unitOfWork)
    {
        _networkRepository = networkRepository;
        _settingsRepository = settingsRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<NetworkCashbackSettingsResponse?> HandleAsync(
        UpdateNetworkCashbackSettingsCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var network = await _networkRepository.GetByIdAsync(command.AffiliateNetworkId, cancellationToken);

        if (network is null)
        {
            return null;
        }

        var settings = await _settingsRepository.GetTrackedByNetworkIdAsync(
            command.AffiliateNetworkId, cancellationToken);

        if (settings is null)
        {
            settings = new NetworkCashbackSettings
            {
                AffiliateNetworkId = command.AffiliateNetworkId,
                UserSharePercent = command.UserSharePercent,
                ConfirmationWindowDays = command.ConfirmationWindowDays
            };

            await _settingsRepository.AddAsync(settings, cancellationToken);
        }
        else
        {
            settings.UserSharePercent = command.UserSharePercent;
            settings.ConfirmationWindowDays = command.ConfirmationWindowDays;
            settings.UpdatedAt = DateTime.UtcNow;
        }

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return GetNetworkCashbackSettingsQueryHandler.ToResponse(settings);
    }
}
