using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Categories;

namespace SmartMoney.Application.Features.Categories.CreateCategory;

public sealed class CreateCategoryCommand : ICommand<CategoryAdminResponse>
{
    public string Name { get; }

    public string? Slug { get; }

    public string? Description { get; }

    public string? IconUrl { get; }

    public int DisplayOrder { get; }

    public CreateCategoryCommand(
        string name,
        string? slug,
        string? description,
        string? iconUrl,
        int displayOrder)
    {
        Name = name;
        Slug = slug;
        Description = description;
        IconUrl = iconUrl;
        DisplayOrder = displayOrder;
    }
}
