using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Categories;

namespace SmartMoney.Application.Features.Categories.UpdateCategory;

public sealed class UpdateCategoryCommand : ICommand<CategoryAdminResponse?>
{
    public Guid CategoryId { get; }

    public string Name { get; }

    public string Slug { get; }

    public string? Description { get; }

    public string? IconUrl { get; }

    public int DisplayOrder { get; }

    public bool IsActive { get; }

    public UpdateCategoryCommand(
        Guid categoryId,
        string name,
        string slug,
        string? description,
        string? iconUrl,
        int displayOrder,
        bool isActive)
    {
        CategoryId = categoryId;
        Name = name;
        Slug = slug;
        Description = description;
        IconUrl = iconUrl;
        DisplayOrder = displayOrder;
        IsActive = isActive;
    }
}
