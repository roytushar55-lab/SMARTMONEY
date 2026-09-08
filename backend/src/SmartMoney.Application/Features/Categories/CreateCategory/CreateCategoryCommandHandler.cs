using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Categories;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Categories.CreateCategory;

public sealed class CreateCategoryCommandHandler
    : ICommandHandler<CreateCategoryCommand, CategoryAdminResponse>
{
    private readonly ICategoryRepository _categoryRepository;
    private readonly CreateCategoryValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public CreateCategoryCommandHandler(
        ICategoryRepository categoryRepository,
        CreateCategoryValidator validator,
        IUnitOfWork unitOfWork)
    {
        _categoryRepository = categoryRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<CategoryAdminResponse> HandleAsync(
        CreateCategoryCommand command,
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

        if (await _categoryRepository.NameExistsAsync(name, null, cancellationToken))
        {
            throw new InvalidOperationException($"A category named \"{name}\" already exists.");
        }

        if (await _categoryRepository.SlugExistsAsync(slug, null, cancellationToken))
        {
            throw new InvalidOperationException($"The slug \"{slug}\" is already in use.");
        }

        var category = new Category
        {
            Name = name,
            Slug = slug,
            Description = command.Description?.Trim(),
            IconUrl = command.IconUrl?.Trim(),
            DisplayOrder = command.DisplayOrder
        };

        await _categoryRepository.AddAsync(category, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return ToResponse(category);
    }

    internal static CategoryAdminResponse ToResponse(Category category)
    {
        return new CategoryAdminResponse
        {
            Id = category.Id,
            Name = category.Name,
            Slug = category.Slug,
            Description = category.Description,
            IconUrl = category.IconUrl,
            DisplayOrder = category.DisplayOrder,
            IsActive = category.IsActive,
            CreatedAt = category.CreatedAt,
            UpdatedAt = category.UpdatedAt
        };
    }
}
