using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Categories;
using SmartMoney.Application.Features.Categories.CreateCategory;

namespace SmartMoney.Application.Features.Categories.ListCategoriesAdmin;

/// <summary>Admin listing — every category, active and inactive.</summary>
public sealed class ListCategoriesAdminQueryHandler
    : IQueryHandler<ListCategoriesAdminQuery, IReadOnlyList<CategoryAdminResponse>>
{
    private readonly ICategoryRepository _categoryRepository;

    public ListCategoriesAdminQueryHandler(ICategoryRepository categoryRepository)
    {
        _categoryRepository = categoryRepository;
    }

    public async Task<IReadOnlyList<CategoryAdminResponse>> HandleAsync(
        ListCategoriesAdminQuery query,
        CancellationToken cancellationToken)
    {
        var categories = await _categoryRepository.GetAllAsync(cancellationToken);

        return categories
            .Select(CreateCategoryCommandHandler.ToResponse)
            .ToList();
    }
}
