using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Identity.AdminUsers;
using SmartMoney.Application.Contracts.Identity.ChangeUserRole;
using SmartMoney.Application.Features.Identity.ChangeUserRole;
using SmartMoney.Application.Features.Identity.GetUserByEmail;
using SmartMoney.Application.Features.Identity.GetUserDetail;
using SmartMoney.Application.Features.Identity.GetUserStats;
using SmartMoney.Application.Features.Identity.ListUsers;
using SmartMoney.Application.Features.Identity.UpdateUserStatus;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Authorize(Roles = "SuperAdmin")]
public sealed class AdminUsersController : ControllerBase
{
    private readonly ICommandHandler<ChangeUserRoleCommand, ChangeUserRoleResponse?> _changeRoleHandler;
    private readonly IQueryHandler<GetUserByEmailQuery, AdminUserLookupResponse?> _lookupHandler;
    private readonly IQueryHandler<ListUsersQuery, AdminUserListResponse> _listHandler;
    private readonly IQueryHandler<GetUserDetailQuery, AdminUserDetailResponse?> _detailHandler;
    private readonly ICommandHandler<UpdateUserStatusCommand, AdminUserStatusResponse?> _statusHandler;
    private readonly IQueryHandler<GetUserStatsQuery, AdminUserStatsResponse> _statsHandler;

    public AdminUsersController(
        ICommandHandler<ChangeUserRoleCommand, ChangeUserRoleResponse?> changeRoleHandler,
        IQueryHandler<GetUserByEmailQuery, AdminUserLookupResponse?> lookupHandler,
        IQueryHandler<ListUsersQuery, AdminUserListResponse> listHandler,
        IQueryHandler<GetUserDetailQuery, AdminUserDetailResponse?> detailHandler,
        ICommandHandler<UpdateUserStatusCommand, AdminUserStatusResponse?> statusHandler,
        IQueryHandler<GetUserStatsQuery, AdminUserStatsResponse> statsHandler)
    {
        _changeRoleHandler = changeRoleHandler;
        _lookupHandler = lookupHandler;
        _listHandler = listHandler;
        _detailHandler = detailHandler;
        _statusHandler = statusHandler;
        _statsHandler = statsHandler;
    }

    /// <summary>
    /// Paginated listing of all users, newest first.
    /// </summary>
    [HttpGet("api/admin/users")]
    [ProducesResponseType(typeof(AdminUserListResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminUserListResponse>> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null,
        [FromQuery] bool? isActive = null,
        CancellationToken cancellationToken = default)
    {
        var response = await _listHandler.HandleAsync(
            new ListUsersQuery(page, pageSize, search, isActive), cancellationToken);

        return Ok(response);
    }

    /// <summary>
    /// Dashboard KPI tile data: total/active/deactivated users, plus
    /// signups in the trailing 7 days.
    /// </summary>
    [HttpGet("api/admin/users/stats")]
    [ProducesResponseType(typeof(AdminUserStatsResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminUserStatsResponse>> GetStats(
        CancellationToken cancellationToken)
    {
        var response = await _statsHandler.HandleAsync(
            new GetUserStatsQuery(), cancellationToken);

        return Ok(response);
    }

    /// <summary>
    /// Looks up a single user by email, to find their id before promoting or
    /// demoting them. Moved off the bare "api/admin/users" route (now the
    /// paginated listing above) to this dedicated path.
    /// </summary>
    [HttpGet("api/admin/users/lookup")]
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

    /// <summary>
    /// Single user detail: profile, cashback totals by status, and lifetime
    /// wallet withdrawals.
    /// </summary>
    [HttpGet("api/admin/users/{id:guid}")]
    [ProducesResponseType(typeof(AdminUserDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<AdminUserDetailResponse>> GetById(
        Guid id,
        CancellationToken cancellationToken)
    {
        var user = await _detailHandler.HandleAsync(
            new GetUserDetailQuery(id), cancellationToken);

        if (user is null)
        {
            return NotFound(new { message = "User not found." });
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

    /// <summary>
    /// Activates or deactivates a user. An admin cannot deactivate their own
    /// account (same self-protection pattern as <see cref="ChangeRole"/>).
    /// </summary>
    [HttpPost("api/admin/users/{id:guid}/status")]
    [ProducesResponseType(typeof(AdminUserStatusResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AdminUserStatusResponse>> ChangeStatus(
        Guid id,
        [FromBody] UpdateUserStatusRequest request,
        CancellationToken cancellationToken)
    {
        string? actingUserIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (!Guid.TryParse(actingUserIdClaim, out Guid actingUserId))
        {
            return Unauthorized();
        }

        var command = new UpdateUserStatusCommand(id, request.IsActive, actingUserId);

        try
        {
            var response = await _statusHandler.HandleAsync(command, cancellationToken);

            if (response is null)
            {
                return NotFound(new { message = "User not found." });
            }

            return Ok(response);
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new { message = exception.Message });
        }
    }
}
