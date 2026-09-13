using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Categories;
using SmartMoney.Application.Features.Categories.CreateCategory;
using SmartMoney.Application.Features.Categories.ListCategoriesAdmin;
using SmartMoney.Application.Features.Categories.UpdateCategory;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
[Route("api/admin/categories")]
public sealed class AdminCategoriesController : ControllerBase
{
    private readonly IQueryHandler<ListCategoriesAdminQuery, IReadOnlyList<CategoryAdminResponse>> _listHandler;
    private readonly ICommandHandler<CreateCategoryCommand, CategoryAdminResponse> _createHandler;
    private readonly ICommandHandler<UpdateCategoryCommand, CategoryAdminResponse?> _updateHandler;

    public AdminCategoriesController(
        IQueryHandler<ListCategoriesAdminQuery, IReadOnlyList<CategoryAdminResponse>> listHandler,
        ICommandHandler<CreateCategoryCommand, CategoryAdminResponse> createHandler,
        ICommandHandler<UpdateCategoryCommand, CategoryAdminResponse?> updateHandler)
    {
        _listHandler = listHandler;
        _createHandler = createHandler;
        _updateHandler = updateHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<CategoryAdminResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<CategoryAdminResponse>>> List(
        CancellationToken cancellationToken)
    {
        var categories = await _listHandler.HandleAsync(
            new ListCategoriesAdminQuery(), cancellationToken);

        return Ok(categories);
    }

    [HttpPost]
    [ProducesResponseType(typeof(CategoryAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<CategoryAdminResponse>> Create(
        [FromBody] CreateCategoryRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateCategoryCommand(
            request.Name,
            request.Slug,
            request.Description,
            request.IconUrl,
            request.DisplayOrder);

        try
        {
            var category = await _createHandler.HandleAsync(command, cancellationToken);

            return Ok(category);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new { message = exception.Message });
        }
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(CategoryAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<CategoryAdminResponse>> Update(
        Guid id,
        [FromBody] UpdateCategoryRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateCategoryCommand(
            id,
            request.Name,
            request.Slug,
            request.Description,
            request.IconUrl,
            request.DisplayOrder,
            request.IsActive);

        try
        {
            var category = await _updateHandler.HandleAsync(command, cancellationToken);

            if (category is null)
            {
                return NotFound(new { message = "Category not found." });
            }

            return Ok(category);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new { message = exception.Message });
        }
    }
}
