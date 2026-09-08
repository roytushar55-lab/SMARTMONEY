using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Categories;

namespace SmartMoney.Application.Features.Categories.ListCategoriesAdmin;

public sealed class ListCategoriesAdminQuery : IQuery<IReadOnlyList<CategoryAdminResponse>>
{
}
