using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.AffiliateNetworks;
using SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;
using SmartMoney.Application.Features.AffiliateNetworks.ListAffiliateNetworksAdmin;
using SmartMoney.Application.Features.AffiliateNetworks.UpdateAffiliateNetwork;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// SuperAdmin-only — registering a provider or repointing its code controls
/// which webhooks get trusted with commission attribution, so this stays out
/// of the regular Admin role's reach.
/// </summary>
[ApiController]
[Authorize(Roles = "SuperAdmin")]
[Route("api/admin/affiliate-networks")]
public sealed class AdminAffiliateNetworksController : ControllerBase
{
    private readonly IQueryHandler<ListAffiliateNetworksAdminQuery, IReadOnlyList<AffiliateNetworkAdminResponse>> _listHandler;
    private readonly ICommandHandler<CreateAffiliateNetworkCommand, AffiliateNetworkAdminResponse> _createHandler;
    private readonly ICommandHandler<UpdateAffiliateNetworkCommand, AffiliateNetworkAdminResponse?> _updateHandler;

    public AdminAffiliateNetworksController(
        IQueryHandler<ListAffiliateNetworksAdminQuery, IReadOnlyList<AffiliateNetworkAdminResponse>> listHandler,
        ICommandHandler<CreateAffiliateNetworkCommand, AffiliateNetworkAdminResponse> createHandler,
        ICommandHandler<UpdateAffiliateNetworkCommand, AffiliateNetworkAdminResponse?> updateHandler)
    {
        _listHandler = listHandler;
        _createHandler = createHandler;
        _updateHandler = updateHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<AffiliateNetworkAdminResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AffiliateNetworkAdminResponse>>> List(
        CancellationToken cancellationToken)
    {
        var networks = await _listHandler.HandleAsync(
            new ListAffiliateNetworksAdminQuery(), cancellationToken);

        return Ok(networks);
    }

    [HttpPost]
    [ProducesResponseType(typeof(AffiliateNetworkAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AffiliateNetworkAdminResponse>> Create(
        [FromBody] CreateAffiliateNetworkRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateAffiliateNetworkCommand(request.Name, request.Code);

        try
        {
            var network = await _createHandler.HandleAsync(command, cancellationToken);

            return Ok(network);
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
    [ProducesResponseType(typeof(AffiliateNetworkAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AffiliateNetworkAdminResponse>> Update(
        Guid id,
        [FromBody] UpdateAffiliateNetworkRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateAffiliateNetworkCommand(
            id, request.Name, request.Code, request.IsActive);

        try
        {
            var network = await _updateHandler.HandleAsync(command, cancellationToken);

            if (network is null)
            {
                return NotFound(new { message = "Affiliate network not found." });
            }

            return Ok(network);
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
