using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.CashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.GetNetworkCashbackSettings;

namespace SmartMoney.Application.Features.CashbackSettings.UpdateCashbackOverride;

/// <summary>
/// Null response = the override does not exist, or exists under a different
/// network than the one in the route — the controller treats both as 404 so
/// an admin can't discover/edit another network's override id by guessing.
/// </summary>
public sealed class UpdateCashbackOverrideCommandHandler
    : ICommandHandler<UpdateCashbackOverrideCommand, CashbackRateOverrideResponse?>
{
    private readonly ICashbackRateOverrideRepository _overrideRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly IStoreRepository _storeRepository;
    private readonly UpdateCashbackOverrideValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateCashbackOverrideCommandHandler(
        ICashbackRateOverrideRepository overrideRepository,
        ICategoryRepository categoryRepository,
        IStoreRepository storeRepository,
        UpdateCashbackOverrideValidator validator,
        IUnitOfWork unitOfWork)
    {
        _overrideRepository = overrideRepository;
        _categoryRepository = categoryRepository;
        _storeRepository = storeRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<CashbackRateOverrideResponse?> HandleAsync(
        UpdateCashbackOverrideCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var @override = await _overrideRepository.GetByIdAsync(command.OverrideId, cancellationToken);

        if (@override is null || @override.AffiliateNetworkId != command.AffiliateNetworkId)
        {
            return null;
        }

        @override.UserSharePercent = command.UserSharePercent;
        @override.ConfirmationWindowDays = command.ConfirmationWindowDays;
        @override.IsActive = command.IsActive;
        @override.UpdatedAt = DateTime.UtcNow;

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var store = await _storeRepository.GetByIdAsync(@override.StoreId, cancellationToken);
        var category = @override.CategoryId is Guid categoryId
            ? await _categoryRepository.GetByIdAsync(categoryId, cancellationToken)
            : null;

        return new CashbackRateOverrideResponse
        {
            Id = @override.Id,
            AffiliateNetworkId = @override.AffiliateNetworkId,
            StoreId = @override.StoreId,
            StoreName = store?.Name ?? string.Empty,
            CategoryId = @override.CategoryId,
            CategoryName = category?.Name,
            UserSharePercent = @override.UserSharePercent,
            ConfirmationWindowDays = @override.ConfirmationWindowDays,
            IsActive = @override.IsActive,
            CreatedAt = @override.CreatedAt,
            UpdatedAt = @override.UpdatedAt
        };
    }
}
