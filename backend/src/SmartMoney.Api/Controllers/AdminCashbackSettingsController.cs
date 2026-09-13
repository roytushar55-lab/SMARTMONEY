using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.CashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.GetCashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.UpdateCashbackSettings;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
[Route("api/admin/cashback-settings")]
public sealed class AdminCashbackSettingsController : ControllerBase
{
    private readonly IQueryHandler<GetCashbackSettingsQuery, CashbackSettingsResponse?> _getHandler;
    private readonly ICommandHandler<UpdateCashbackSettingsCommand, CashbackSettingsResponse?> _updateHandler;

    public AdminCashbackSettingsController(
        IQueryHandler<GetCashbackSettingsQuery, CashbackSettingsResponse?> getHandler,
        ICommandHandler<UpdateCashbackSettingsCommand, CashbackSettingsResponse?> updateHandler)
    {
        _getHandler = getHandler;
        _updateHandler = updateHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(CashbackSettingsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CashbackSettingsResponse>> Get(
        CancellationToken cancellationToken)
    {
        var settings = await _getHandler.HandleAsync(
            new GetCashbackSettingsQuery(), cancellationToken);

        if (settings is null)
        {
            return NotFound(new { message = "Cashback settings have not been seeded." });
        }

        return Ok(settings);
    }

    [HttpPut]
    [ProducesResponseType(typeof(CashbackSettingsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CashbackSettingsResponse>> Update(
        [FromBody] UpdateCashbackSettingsRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateCashbackSettingsCommand(
            request.UserSharePercent,
            request.ConfirmationWindowDays);

        try
        {
            var settings = await _updateHandler.HandleAsync(command, cancellationToken);

            if (settings is null)
            {
                return NotFound(new { message = "Cashback settings have not been seeded." });
            }

            return Ok(settings);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
    }
}
