using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.AffiliateNetworks;
using SmartMoney.Application.Contracts.CashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.CreateCashbackOverride;
using SmartMoney.Application.Features.CashbackSettings.DeleteCashbackOverride;
using SmartMoney.Application.Features.CashbackSettings.GetNetworkCashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.ListNetworks;
using SmartMoney.Application.Features.CashbackSettings.UpdateCashbackOverride;
using SmartMoney.Application.Features.CashbackSettings.UpdateNetworkCashbackSettings;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// The network and store/category rungs of the cashback rate hierarchy —
/// system-wide settings stay on <see cref="AdminCashbackSettingsController"/>.
/// </summary>
[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
[Route("api/admin/cashback-settings/networks")]
public sealed class AdminNetworkCashbackSettingsController : ControllerBase
{
    private readonly IQueryHandler<ListNetworksQuery, IReadOnlyList<AffiliateNetworkAdminResponse>> _listNetworksHandler;
    private readonly IQueryHandler<GetNetworkCashbackSettingsQuery, NetworkCashbackSettingsDetailResponse?> _getHandler;
    private readonly ICommandHandler<UpdateNetworkCashbackSettingsCommand, NetworkCashbackSettingsResponse?> _updateNetworkHandler;
    private readonly ICommandHandler<CreateCashbackOverrideCommand, CashbackRateOverrideResponse> _createOverrideHandler;
    private readonly ICommandHandler<UpdateCashbackOverrideCommand, CashbackRateOverrideResponse?> _updateOverrideHandler;
    private readonly ICommandHandler<DeleteCashbackOverrideCommand, bool> _deleteOverrideHandler;

    public AdminNetworkCashbackSettingsController(
        IQueryHandler<ListNetworksQuery, IReadOnlyList<AffiliateNetworkAdminResponse>> listNetworksHandler,
        IQueryHandler<GetNetworkCashbackSettingsQuery, NetworkCashbackSettingsDetailResponse?> getHandler,
        ICommandHandler<UpdateNetworkCashbackSettingsCommand, NetworkCashbackSettingsResponse?> updateNetworkHandler,
        ICommandHandler<CreateCashbackOverrideCommand, CashbackRateOverrideResponse> createOverrideHandler,
        ICommandHandler<UpdateCashbackOverrideCommand, CashbackRateOverrideResponse?> updateOverrideHandler,
        ICommandHandler<DeleteCashbackOverrideCommand, bool> deleteOverrideHandler)
    {
        _listNetworksHandler = listNetworksHandler;
        _getHandler = getHandler;
        _updateNetworkHandler = updateNetworkHandler;
        _createOverrideHandler = createOverrideHandler;
        _updateOverrideHandler = updateOverrideHandler;
        _deleteOverrideHandler = deleteOverrideHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<AffiliateNetworkAdminResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AffiliateNetworkAdminResponse>>> ListNetworks(
        CancellationToken cancellationToken)
    {
        var networks = await _listNetworksHandler.HandleAsync(new ListNetworksQuery(), cancellationToken);

        return Ok(networks);
    }

    [HttpGet("{networkId:guid}")]
    [ProducesResponseType(typeof(NetworkCashbackSettingsDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<NetworkCashbackSettingsDetailResponse>> GetNetworkSettings(
        Guid networkId,
        CancellationToken cancellationToken)
    {
        var detail = await _getHandler.HandleAsync(
            new GetNetworkCashbackSettingsQuery(networkId), cancellationToken);

        if (detail is null)
        {
            return NotFound(new { message = "Affiliate network not found." });
        }

        return Ok(detail);
    }

    [HttpPut("{networkId:guid}")]
    [ProducesResponseType(typeof(NetworkCashbackSettingsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<NetworkCashbackSettingsResponse>> UpdateNetworkSettings(
        Guid networkId,
        [FromBody] UpdateNetworkCashbackSettingsRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateNetworkCashbackSettingsCommand(
            networkId, request.UserSharePercent, request.ConfirmationWindowDays);

        try
        {
            var settings = await _updateNetworkHandler.HandleAsync(command, cancellationToken);

            if (settings is null)
            {
                return NotFound(new { message = "Affiliate network not found." });
            }

            return Ok(settings);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
    }

    [HttpPost("{networkId:guid}/overrides")]
    [ProducesResponseType(typeof(CashbackRateOverrideResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<CashbackRateOverrideResponse>> CreateOverride(
        Guid networkId,
        [FromBody] CreateCashbackOverrideRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateCashbackOverrideCommand(
            networkId,
            request.StoreId,
            request.CategoryId,
            request.UserSharePercent,
            request.ConfirmationWindowDays);

        try
        {
            var @override = await _createOverrideHandler.HandleAsync(command, cancellationToken);

            return Ok(@override);
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

    [HttpPut("{networkId:guid}/overrides/{overrideId:guid}")]
    [ProducesResponseType(typeof(CashbackRateOverrideResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CashbackRateOverrideResponse>> UpdateOverride(
        Guid networkId,
        Guid overrideId,
        [FromBody] UpdateCashbackOverrideRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateCashbackOverrideCommand(
            networkId,
            overrideId,
            request.UserSharePercent,
            request.ConfirmationWindowDays,
            request.IsActive);

        try
        {
            var @override = await _updateOverrideHandler.HandleAsync(command, cancellationToken);

            if (@override is null)
            {
                return NotFound(new { message = "Cashback rate override not found." });
            }

            return Ok(@override);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
    }

    [HttpDelete("{networkId:guid}/overrides/{overrideId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteOverride(
        Guid networkId,
        Guid overrideId,
        CancellationToken cancellationToken)
    {
        var command = new DeleteCashbackOverrideCommand(networkId, overrideId);

        var deleted = await _deleteOverrideHandler.HandleAsync(command, cancellationToken);

        if (!deleted)
        {
            return NotFound(new { message = "Cashback rate override not found." });
        }

        return NoContent();
    }
}
