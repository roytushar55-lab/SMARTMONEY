using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Stores;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Stores.CreateStore;

public sealed class CreateStoreCommandHandler
    : ICommandHandler<CreateStoreCommand, StoreAdminResponse>
{
    private readonly IStoreRepository _storeRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly CreateStoreValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public CreateStoreCommandHandler(
        IStoreRepository storeRepository,
        ICategoryRepository categoryRepository,
        CreateStoreValidator validator,
        IUnitOfWork unitOfWork)
    {
        _storeRepository = storeRepository;
        _categoryRepository = categoryRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<StoreAdminResponse> HandleAsync(
        CreateStoreCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        string name = command.Name.Trim();
        string slug = string.IsNullOrWhiteSpace(command.Slug)
            ? SlugGenerator.Generate(name)
            : command.Slug.Trim().ToLowerInvariant();

        if (string.IsNullOrEmpty(slug))
        {
            throw new ArgumentException("A usable slug could not be generated from the name.");
        }

        if (await _storeRepository.NameExistsAsync(name, null, cancellationToken))
        {
            throw new InvalidOperationException($"A store named \"{name}\" already exists.");
        }

        if (await _storeRepository.SlugExistsAsync(slug, null, cancellationToken))
        {
            throw new InvalidOperationException($"The slug \"{slug}\" is already in use.");
        }

        var categoryIds = command.CategoryIds.Distinct().ToList();

        if (categoryIds.Count > 0 &&
            !await _categoryRepository.AllExistAsync(categoryIds, cancellationToken))
        {
            throw new ArgumentException("One or more categories do not exist.");
        }

        var store = new Store
        {
            Name = name,
            Slug = slug,
            ShortDescription = command.ShortDescription?.Trim(),
            Description = command.Description?.Trim(),
            LogoUrl = command.LogoUrl?.Trim(),
            BannerUrl = command.BannerUrl?.Trim(),
            WebsiteUrl = command.WebsiteUrl.Trim(),
            DefaultCashbackText = command.DefaultCashbackText?.Trim(),
            IsFeatured = command.IsFeatured,
            DisplayOrder = command.DisplayOrder
        };

        foreach (var categoryId in categoryIds)
        {
            store.StoreCategories.Add(new StoreCategory
            {
                StoreId = store.Id,
                CategoryId = categoryId
            });
        }

        await _storeRepository.AddAsync(store, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return ToResponse(store);
    }

    internal static StoreAdminResponse ToResponse(Store store)
    {
        return new StoreAdminResponse
        {
            Id = store.Id,
            Name = store.Name,
            Slug = store.Slug,
            ShortDescription = store.ShortDescription,
            Description = store.Description,
            LogoUrl = store.LogoUrl,
            BannerUrl = store.BannerUrl,
            WebsiteUrl = store.WebsiteUrl,
            DefaultCashbackText = store.DefaultCashbackText,
            IsFeatured = store.IsFeatured,
            DisplayOrder = store.DisplayOrder,
            IsActive = store.IsActive,
            CategoryIds = store.StoreCategories.Select(sc => sc.CategoryId).ToList(),
            CreatedAt = store.CreatedAt,
            UpdatedAt = store.UpdatedAt
        };
    }
}
