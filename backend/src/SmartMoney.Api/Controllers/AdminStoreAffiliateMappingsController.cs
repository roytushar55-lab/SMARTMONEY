using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;
using SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;
using SmartMoney.Application.Features.StoreAffiliateMappings.ListStoreAffiliateMappingsAdmin;
using SmartMoney.Application.Features.StoreAffiliateMappings.UpdateStoreAffiliateMapping;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// SuperAdmin-only — a mapping controls which merchant id earns commission
/// attribution for a store, so it carries the same trust boundary as
/// affiliate networks themselves.
/// </summary>
[ApiController]
[Authorize(Roles = "SuperAdmin")]
[Route("api/admin/store-affiliate-mappings")]
public sealed class AdminStoreAffiliateMappingsController : ControllerBase
{
    private readonly IQueryHandler<ListStoreAffiliateMappingsAdminQuery, IReadOnlyList<StoreAffiliateMappingAdminResponse>> _listHandler;
    private readonly ICommandHandler<CreateStoreAffiliateMappingCommand, StoreAffiliateMappingAdminResponse?> _createHandler;
    private readonly ICommandHandler<UpdateStoreAffiliateMappingCommand, StoreAffiliateMappingAdminResponse?> _updateHandler;

    public AdminStoreAffiliateMappingsController(
        IQueryHandler<ListStoreAffiliateMappingsAdminQuery, IReadOnlyList<StoreAffiliateMappingAdminResponse>> listHandler,
        ICommandHandler<CreateStoreAffiliateMappingCommand, StoreAffiliateMappingAdminResponse?> createHandler,
        ICommandHandler<UpdateStoreAffiliateMappingCommand, StoreAffiliateMappingAdminResponse?> updateHandler)
    {
        _listHandler = listHandler;
        _createHandler = createHandler;
        _updateHandler = updateHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<StoreAffiliateMappingAdminResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<StoreAffiliateMappingAdminResponse>>> List(
        [FromQuery] Guid? storeId,
        CancellationToken cancellationToken)
    {
        var mappings = await _listHandler.HandleAsync(
            new ListStoreAffiliateMappingsAdminQuery(storeId), cancellationToken);

        return Ok(mappings);
    }

    [HttpPost]
    [ProducesResponseType(typeof(StoreAffiliateMappingAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<StoreAffiliateMappingAdminResponse>> Create(
        [FromBody] CreateStoreAffiliateMappingRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateStoreAffiliateMappingCommand(
            request.StoreId,
            request.AffiliateNetworkId,
            request.ExternalMerchantId,
            request.ExternalMerchantName,
            request.MerchantUrl);

        try
        {
            var mapping = await _createHandler.HandleAsync(command, cancellationToken);

            if (mapping is null)
            {
                return NotFound(new { message = "Store or affiliate network not found." });
            }

            return Ok(mapping);
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
    [ProducesResponseType(typeof(StoreAffiliateMappingAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<StoreAffiliateMappingAdminResponse>> Update(
        Guid id,
        [FromBody] UpdateStoreAffiliateMappingRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateStoreAffiliateMappingCommand(
            id,
            request.ExternalMerchantId,
            request.ExternalMerchantName,
            request.MerchantUrl,
            request.IsActive);

        try
        {
            var mapping = await _updateHandler.HandleAsync(command, cancellationToken);

            if (mapping is null)
            {
                return NotFound(new { message = "Mapping not found." });
            }

            return Ok(mapping);
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
