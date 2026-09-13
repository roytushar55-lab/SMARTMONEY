using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Stores;
using SmartMoney.Application.Features.Stores.CreateStore;
using SmartMoney.Application.Features.Stores.ListStoresAdmin;
using SmartMoney.Application.Features.Stores.UpdateStore;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
[Route("api/admin/stores")]
public sealed class AdminStoresController : ControllerBase
{
    private readonly IQueryHandler<ListStoresAdminQuery, IReadOnlyList<StoreAdminResponse>> _listHandler;
    private readonly ICommandHandler<CreateStoreCommand, StoreAdminResponse> _createHandler;
    private readonly ICommandHandler<UpdateStoreCommand, StoreAdminResponse?> _updateHandler;

    public AdminStoresController(
        IQueryHandler<ListStoresAdminQuery, IReadOnlyList<StoreAdminResponse>> listHandler,
        ICommandHandler<CreateStoreCommand, StoreAdminResponse> createHandler,
        ICommandHandler<UpdateStoreCommand, StoreAdminResponse?> updateHandler)
    {
        _listHandler = listHandler;
        _createHandler = createHandler;
        _updateHandler = updateHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<StoreAdminResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<StoreAdminResponse>>> List(
        CancellationToken cancellationToken)
    {
        var stores = await _listHandler.HandleAsync(new ListStoresAdminQuery(), cancellationToken);

        return Ok(stores);
    }

    [HttpPost]
    [ProducesResponseType(typeof(StoreAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<StoreAdminResponse>> Create(
        [FromBody] CreateStoreRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateStoreCommand(
            request.Name,
            request.Slug,
            request.ShortDescription,
            request.Description,
            request.LogoUrl,
            request.BannerUrl,
            request.WebsiteUrl,
            request.DefaultCashbackText,
            request.IsFeatured,
            request.DisplayOrder,
            request.CategoryIds);

        try
        {
            var store = await _createHandler.HandleAsync(command, cancellationToken);

            return Ok(store);
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
    [ProducesResponseType(typeof(StoreAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<StoreAdminResponse>> Update(
        Guid id,
        [FromBody] UpdateStoreRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateStoreCommand(
            id,
            request.Name,
            request.Slug,
            request.ShortDescription,
            request.Description,
            request.LogoUrl,
            request.BannerUrl,
            request.WebsiteUrl,
            request.DefaultCashbackText,
            request.IsFeatured,
            request.DisplayOrder,
            request.IsActive,
            request.CategoryIds);

        try
        {
            var store = await _updateHandler.HandleAsync(command, cancellationToken);

            if (store is null)
            {
                return NotFound(new { message = "Store not found." });
            }

            return Ok(store);
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
