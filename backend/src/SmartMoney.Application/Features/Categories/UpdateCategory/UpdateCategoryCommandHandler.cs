using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Categories;
using SmartMoney.Application.Features.Categories.CreateCategory;

namespace SmartMoney.Application.Features.Categories.UpdateCategory;

/// <summary>Null response = category not found. Also the activate/deactivate toggle.</summary>
public sealed class UpdateCategoryCommandHandler
    : ICommandHandler<UpdateCategoryCommand, CategoryAdminResponse?>
{
    private readonly ICategoryRepository _categoryRepository;
    private readonly UpdateCategoryValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateCategoryCommandHandler(
        ICategoryRepository categoryRepository,
        UpdateCategoryValidator validator,
        IUnitOfWork unitOfWork)
    {
        _categoryRepository = categoryRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<CategoryAdminResponse?> HandleAsync(
        UpdateCategoryCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var category = await _categoryRepository.GetByIdAsync(
            command.CategoryId, cancellationToken);

        if (category is null)
        {
            return null;
        }

        string name = command.Name.Trim();
        string slug = command.Slug.Trim().ToLowerInvariant();

        if (await _categoryRepository.NameExistsAsync(name, category.Id, cancellationToken))
        {
            throw new InvalidOperationException($"A category named \"{name}\" already exists.");
        }

        if (await _categoryRepository.SlugExistsAsync(slug, category.Id, cancellationToken))
        {
            throw new InvalidOperationException($"The slug \"{slug}\" is already in use.");
        }

        category.Name = name;
        category.Slug = slug;
        category.Description = command.Description?.Trim();
        category.IconUrl = command.IconUrl?.Trim();
        category.DisplayOrder = command.DisplayOrder;
        category.IsActive = command.IsActive;
        category.UpdatedAt = DateTime.UtcNow;

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return CreateCategoryCommandHandler.ToResponse(category);
    }
}
