using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.ChangeUserRole;
using SmartMoney.Application.Features.Identity.ChangeUserRole;
using SmartMoney.Application.Features.Identity.GetUserByEmail;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Authorize(Roles = "SuperAdmin")]
public sealed class AdminUsersController : ControllerBase
{
    private readonly ICommandHandler<ChangeUserRoleCommand, ChangeUserRoleResponse?> _changeRoleHandler;
    private readonly IQueryHandler<GetUserByEmailQuery, AdminUserLookupResponse?> _lookupHandler;

    public AdminUsersController(
        ICommandHandler<ChangeUserRoleCommand, ChangeUserRoleResponse?> changeRoleHandler,
        IQueryHandler<GetUserByEmailQuery, AdminUserLookupResponse?> lookupHandler)
    {
        _changeRoleHandler = changeRoleHandler;
        _lookupHandler = lookupHandler;
    }

    [HttpGet("api/admin/users")]
    [ProducesResponseType(typeof(AdminUserLookupResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<AdminUserLookupResponse>> GetByEmail(
        [FromQuery] string email,
        CancellationToken cancellationToken)
    {
        var user = await _lookupHandler.HandleAsync(
            new GetUserByEmailQuery(email), cancellationToken);

        if (user is null)
        {
            return NotFound(new { message = "No user with that email." });
        }

        return Ok(user);
    }

    [HttpPost("api/admin/users/{id:guid}/role")]
    [ProducesResponseType(typeof(ChangeUserRoleResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<ChangeUserRoleResponse>> ChangeRole(
        Guid id,
        [FromBody] ChangeUserRoleRequest request,
        CancellationToken cancellationToken)
    {
        string? actingUserIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (!Guid.TryParse(actingUserIdClaim, out Guid actingUserId))
        {
            return Unauthorized();
        }

        var command = new ChangeUserRoleCommand(id, request.Role, actingUserId);

        try
        {
            var response = await _changeRoleHandler.HandleAsync(
                command, cancellationToken);

            if (response is null)
            {
                return NotFound(new { message = "User not found." });
            }

            return Ok(response);
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
