using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Application.Features.Withdrawals.CancelWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetMyWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetMyWithdrawals;
using SmartMoney.Application.Features.Withdrawals.PreviewWithdrawal;
using SmartMoney.Application.Features.Withdrawals.RequestWithdrawal;

namespace SmartMoney.Api.Controllers;

/// <summary>A user's own withdrawals: preview the cost, request, list, cancel.</summary>
[ApiController]
[Authorize]
[Route("api/withdrawals")]
public sealed class WithdrawalsController : ControllerBase
{
    private readonly ICommandHandler<RequestWithdrawalCommand, WithdrawalResponse> _requestHandler;
    private readonly ICommandHandler<CancelWithdrawalCommand, WithdrawalDecisionResponse> _cancelHandler;
    private readonly IQueryHandler<GetMyWithdrawalsQuery, WithdrawalListResponse> _listHandler;
    private readonly IQueryHandler<GetMyWithdrawalQuery, WithdrawalResponse?> _getHandler;
    private readonly IQueryHandler<PreviewWithdrawalQuery, WithdrawalPreviewResponse> _previewHandler;

    public WithdrawalsController(
        ICommandHandler<RequestWithdrawalCommand, WithdrawalResponse> requestHandler,
        ICommandHandler<CancelWithdrawalCommand, WithdrawalDecisionResponse> cancelHandler,
        IQueryHandler<GetMyWithdrawalsQuery, WithdrawalListResponse> listHandler,
        IQueryHandler<GetMyWithdrawalQuery, WithdrawalResponse?> getHandler,
        IQueryHandler<PreviewWithdrawalQuery, WithdrawalPreviewResponse> previewHandler)
    {
        _requestHandler = requestHandler;
        _cancelHandler = cancelHandler;
        _listHandler = listHandler;
        _getHandler = getHandler;
        _previewHandler = previewHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(WithdrawalListResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<WithdrawalListResponse>> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        if (!TryGetUserId(out Guid userId))
        {
            return Unauthorized();
        }

        var response = await _listHandler.HandleAsync(
            new GetMyWithdrawalsQuery(userId, page, pageSize), cancellationToken);

        return Ok(response);
    }

    /// <summary>The fee and the amount the user would receive, plus whether it is allowed.</summary>
    [HttpGet("preview")]
    [ProducesResponseType(typeof(WithdrawalPreviewResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<WithdrawalPreviewResponse>> Preview(
        [FromQuery] decimal amount,
        CancellationToken cancellationToken = default)
    {
        if (!TryGetUserId(out Guid userId))
        {
            return Unauthorized();
        }

        try
        {
            var response = await _previewHandler.HandleAsync(
                new PreviewWithdrawalQuery(userId, amount), cancellationToken);

            return Ok(response);
        }
        catch (KeyNotFoundException exception)
        {
            return NotFound(new { message = exception.Message });
        }
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(WithdrawalResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<WithdrawalResponse>> Get(
        Guid id,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(out Guid userId))
        {
            return Unauthorized();
        }

        var response = await _getHandler.HandleAsync(
            new GetMyWithdrawalQuery(userId, id), cancellationToken);

        return response is null
            ? NotFound(new { message = "Withdrawal was not found." })
            : Ok(response);
    }

    /// <summary>
    /// Asks to withdraw. The password is required again, so a stolen session
    /// alone cannot move money; the endpoint is rate-limited for the same reason.
    /// </summary>
    [HttpPost]
    [EnableRateLimiting("withdrawal")]
    [ProducesResponseType(typeof(WithdrawalResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<WithdrawalResponse>> Create(
        [FromBody] RequestWithdrawalRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(out Guid userId))
        {
            return Unauthorized();
        }

        try
        {
            var response = await _requestHandler.HandleAsync(
                new RequestWithdrawalCommand(userId, request), cancellationToken);

            return Created($"api/withdrawals/{response.Id}", response);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
        catch (KeyNotFoundException exception)
        {
            return NotFound(new { message = exception.Message });
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new { message = exception.Message });
        }
    }

    [HttpPost("{id:guid}/cancel")]
    [ProducesResponseType(typeof(WithdrawalDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<WithdrawalDecisionResponse>> Cancel(
        Guid id,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(out Guid userId))
        {
            return Unauthorized();
        }

        try
        {
            var response = await _cancelHandler.HandleAsync(
                new CancelWithdrawalCommand(userId, id), cancellationToken);

            return Ok(response);
        }
        catch (KeyNotFoundException exception)
        {
            return NotFound(new { message = exception.Message });
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new { message = exception.Message });
        }
    }

    private bool TryGetUserId(out Guid userId)
    {
        return Guid.TryParse(
            User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out userId);
    }
}
