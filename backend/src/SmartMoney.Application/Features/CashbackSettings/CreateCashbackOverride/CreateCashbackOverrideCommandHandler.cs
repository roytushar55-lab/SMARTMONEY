using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.CashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.GetNetworkCashbackSettings;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.CashbackSettings.CreateCashbackOverride;

/// <summary>
/// Most-specific rung of the cashback hierarchy: a rate for one store
/// (optionally narrowed to one category) under one network. Throws
/// <see cref="ArgumentException"/> for validation failures,
/// <see cref="InvalidOperationException"/> when the network/store/category
/// combination doesn't exist or already has an override.
/// </summary>
public sealed class CreateCashbackOverrideCommandHandler
    : ICommandHandler<CreateCashbackOverrideCommand, CashbackRateOverrideResponse>
{
    private readonly IAffiliateNetworkRepository _networkRepository;
    private readonly IStoreRepository _storeRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly ICashbackRateOverrideRepository _overrideRepository;
    private readonly CreateCashbackOverrideValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public CreateCashbackOverrideCommandHandler(
        IAffiliateNetworkRepository networkRepository,
        IStoreRepository storeRepository,
        ICategoryRepository categoryRepository,
        ICashbackRateOverrideRepository overrideRepository,
        CreateCashbackOverrideValidator validator,
        IUnitOfWork unitOfWork)
    {
        _networkRepository = networkRepository;
        _storeRepository = storeRepository;
        _categoryRepository = categoryRepository;
        _overrideRepository = overrideRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<CashbackRateOverrideResponse> HandleAsync(
        CreateCashbackOverrideCommand command,
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
            throw new InvalidOperationException("Affiliate network not found.");
        }

        var store = await _storeRepository.GetByIdAsync(command.StoreId, cancellationToken);

        if (store is null)
        {
            throw new InvalidOperationException("Store not found.");
        }

        if (command.CategoryId is Guid categoryId
            && store.StoreCategories.All(storeCategory => storeCategory.CategoryId != categoryId))
        {
            throw new InvalidOperationException("Category is not assigned to this store.");
        }

        if (await _overrideRepository.ExistsAsync(
                command.AffiliateNetworkId, command.StoreId, command.CategoryId, null, cancellationToken))
        {
            throw new InvalidOperationException(
                "An override for this network, store and category already exists.");
        }

        var @override = new CashbackRateOverride
        {
            AffiliateNetworkId = command.AffiliateNetworkId,
            StoreId = command.StoreId,
            CategoryId = command.CategoryId,
            UserSharePercent = command.UserSharePercent,
            ConfirmationWindowDays = command.ConfirmationWindowDays
        };

        await _overrideRepository.AddAsync(@override, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var category = command.CategoryId is Guid id
            ? await _categoryRepository.GetByIdAsync(id, cancellationToken)
            : null;

        return new CashbackRateOverrideResponse
        {
            Id = @override.Id,
            AffiliateNetworkId = @override.AffiliateNetworkId,
            StoreId = @override.StoreId,
            StoreName = store.Name,
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
