using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Stores;
using SmartMoney.Application.Features.Stores.CreateStore;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Stores.UpdateStore;

/// <summary>Null response = store not found. Also the activate/deactivate toggle.</summary>
public sealed class UpdateStoreCommandHandler
    : ICommandHandler<UpdateStoreCommand, StoreAdminResponse?>
{
    private readonly IStoreRepository _storeRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly UpdateStoreValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateStoreCommandHandler(
        IStoreRepository storeRepository,
        ICategoryRepository categoryRepository,
        UpdateStoreValidator validator,
        IUnitOfWork unitOfWork)
    {
        _storeRepository = storeRepository;
        _categoryRepository = categoryRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<StoreAdminResponse?> HandleAsync(
        UpdateStoreCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var store = await _storeRepository.GetByIdAsync(command.StoreId, cancellationToken);

        if (store is null)
        {
            return null;
        }

        string name = command.Name.Trim();
        string slug = command.Slug.Trim().ToLowerInvariant();

        if (await _storeRepository.NameExistsAsync(name, store.Id, cancellationToken))
        {
            throw new InvalidOperationException($"A store named \"{name}\" already exists.");
        }

        if (await _storeRepository.SlugExistsAsync(slug, store.Id, cancellationToken))
        {
            throw new InvalidOperationException($"The slug \"{slug}\" is already in use.");
        }

        var categoryIds = command.CategoryIds.Distinct().ToList();

        if (categoryIds.Count > 0 &&
            !await _categoryRepository.AllExistAsync(categoryIds, cancellationToken))
        {
            throw new ArgumentException("One or more categories do not exist.");
        }

        int oldDisplayOrder = store.DisplayOrder;

        if (command.DisplayOrder != oldDisplayOrder)
        {
            var siblings = await _storeRepository.GetTrackedByDisplayOrderRangeAsync(
                Math.Min(oldDisplayOrder, command.DisplayOrder),
                Math.Max(oldDisplayOrder, command.DisplayOrder),
                excludeId: store.Id,
                cancellationToken);

            OrderShifter.ShiftForMove(
                siblings, oldDisplayOrder, command.DisplayOrder,
                s => s.DisplayOrder, (s, v) => s.DisplayOrder = v);
        }

        store.Name = name;
        store.Slug = slug;
        store.ShortDescription = command.ShortDescription?.Trim();
        store.Description = command.Description?.Trim();
        store.LogoUrl = command.LogoUrl?.Trim();
        store.BannerUrl = command.BannerUrl?.Trim();
        store.WebsiteUrl = command.WebsiteUrl.Trim();
        store.DefaultCashbackText = command.DefaultCashbackText?.Trim();
        store.IsFeatured = command.IsFeatured;
        store.DisplayOrder = command.DisplayOrder;
        store.IsActive = command.IsActive;
        store.UpdatedAt = DateTime.UtcNow;

        SyncCategories(store, categoryIds);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return CreateStoreCommandHandler.ToResponse(store);
    }

    /// <summary>
    /// StoreCategory has no surrogate key, so syncing means diffing the
    /// tracked collection against the requested set rather than replacing it
    /// wholesale (which would violate the composite-key tracking EF needs).
    /// </summary>
    private static void SyncCategories(Store store, IReadOnlyList<Guid> categoryIds)
    {
        var requestedIds = categoryIds.ToHashSet();

        var toRemove = store.StoreCategories
            .Where(storeCategory => !requestedIds.Contains(storeCategory.CategoryId))
            .ToList();

        foreach (var storeCategory in toRemove)
        {
            store.StoreCategories.Remove(storeCategory);
        }

        var existingIds = store.StoreCategories
            .Select(storeCategory => storeCategory.CategoryId)
            .ToHashSet();

        foreach (var categoryId in requestedIds.Where(id => !existingIds.Contains(id)))
        {
            store.StoreCategories.Add(new StoreCategory
            {
                StoreId = store.Id,
                CategoryId = categoryId
            });
        }
    }
}
