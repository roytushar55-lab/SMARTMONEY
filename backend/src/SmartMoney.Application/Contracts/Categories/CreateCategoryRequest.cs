namespace SmartMoney.Application.Contracts.Categories;

public sealed class CreateCategoryRequest
{
    public string Name { get; set; } = string.Empty;

    /// <summary>Optional — generated from Name when blank.</summary>
    public string? Slug { get; set; }

    public string? Description { get; set; }

    public string? IconUrl { get; set; }

    public int DisplayOrder { get; set; }
}
