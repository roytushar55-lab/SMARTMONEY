using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Cashbacks;
using SmartMoney.Application.Features.Cashbacks;
using SmartMoney.Application.Features.Cashbacks.ApproveCashback;
using SmartMoney.Application.Features.Cashbacks.GetCashbackEvents;
using SmartMoney.Application.Features.Cashbacks.GetCashbackSummary;
using SmartMoney.Application.Features.Cashbacks.ListCashbacks;
using SmartMoney.Application.Features.Cashbacks.RejectCashback;
using SmartMoney.Application.Features.Cashbacks.ReverseCashback;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// The human half of the cashback pipeline: automated ingestion only ever
/// parks cashbacks in AwaitingAdminReview; these endpoints move the money.
/// </summary>
[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
public sealed class AdminCashbacksController : ControllerBase
{
    private readonly IQueryHandler<ListCashbacksQuery, AdminCashbackListResponse> _listHandler;
    private readonly ICommandHandler<ApproveCashbackCommand, CashbackDecisionResponse?> _approveHandler;
    private readonly ICommandHandler<RejectCashbackCommand, CashbackDecisionResponse?> _rejectHandler;
    private readonly ICommandHandler<ReverseCashbackCommand, CashbackDecisionResponse?> _reverseHandler;
    private readonly IQueryHandler<GetCashbackEventsQuery, IReadOnlyList<CashbackEventResponse>?> _eventsHandler;
    private readonly IQueryHandler<GetCashbackSummaryQuery, AdminCashbackSummaryResponse> _summaryHandler;

    public AdminCashbacksController(
        IQueryHandler<ListCashbacksQuery, AdminCashbackListResponse> listHandler,
        IQueryHandler<GetCashbackSummaryQuery, AdminCashbackSummaryResponse> summaryHandler,
        ICommandHandler<ApproveCashbackCommand, CashbackDecisionResponse?> approveHandler,
        ICommandHandler<RejectCashbackCommand, CashbackDecisionResponse?> rejectHandler,
        ICommandHandler<ReverseCashbackCommand, CashbackDecisionResponse?> reverseHandler,
        IQueryHandler<GetCashbackEventsQuery, IReadOnlyList<CashbackEventResponse>?> eventsHandler)
    {
        _listHandler = listHandler;
        _summaryHandler = summaryHandler;
        _approveHandler = approveHandler;
        _rejectHandler = rejectHandler;
        _reverseHandler = reverseHandler;
        _eventsHandler = eventsHandler;
    }

    [HttpGet("api/admin/cashbacks")]
    [ProducesResponseType(typeof(AdminCashbackListResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<AdminCashbackListResponse>> List(
        [FromQuery] string? status = null,
        [FromQuery] string? queue = null,
        [FromQuery] bool overdue = false,
        [FromQuery] string? search = null,
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        CashbackStatus? statusFilter = null;
        CashbackQueue? queueFilter = null;

        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!Enum.TryParse(status.Trim(), ignoreCase: true, out CashbackStatus parsed))
            {
                return BadRequest(new
                {
                    message = "Unknown cashback status. Valid values: "
                        + string.Join(", ", Enum.GetNames<CashbackStatus>()) + "."
                });
            }

            statusFilter = parsed;
        }

        if (!string.IsNullOrWhiteSpace(queue))
        {
            if (!Enum.TryParse(queue.Trim(), ignoreCase: true, out CashbackQueue parsedQueue)
                || !Enum.IsDefined(parsedQueue))
            {
                return BadRequest(new
                {
                    message = "Unknown cashback queue. Valid values: "
                        + string.Join(", ", Enum.GetNames<CashbackQueue>()) + "."
                });
            }

            queueFilter = parsedQueue;
        }

        var filter = new CashbackListFilter
        {
            Status = statusFilter,
            Queue = queueFilter,
            OverdueOnly = overdue,
            Search = search,
            CreatedFrom = ToUtc(from),
            CreatedBefore = ToUtc(to)
        };

        var response = await _listHandler.HandleAsync(
            new ListCashbacksQuery(filter, page, pageSize), cancellationToken);

        return Ok(response);
    }

    /// <summary>
    /// The numbers on top of the review page: how many are in each queue, how
    /// many are overdue, and the confirmed money the network has not paid yet.
    /// </summary>
    [HttpGet("api/admin/cashbacks/summary")]
    [ProducesResponseType(typeof(AdminCashbackSummaryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<AdminCashbackSummaryResponse>> Summary(
        CancellationToken cancellationToken)
    {
        var response = await _summaryHandler.HandleAsync(
            new GetCashbackSummaryQuery(), cancellationToken);

        return Ok(response);
    }

    [HttpPost("api/admin/cashbacks/{id:guid}/approve")]
    [ProducesResponseType(typeof(CashbackDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public Task<ActionResult<CashbackDecisionResponse>> Approve(
        Guid id,
        [FromBody] DecideCashbackRequest? request,
        CancellationToken cancellationToken)
    {
        return DecideAsync(
            request,
            (reviewerId, reason) => _approveHandler.HandleAsync(
                new ApproveCashbackCommand(id, reviewerId, reason, request?.Override == true),
                cancellationToken));
    }

    [HttpPost("api/admin/cashbacks/{id:guid}/reject")]
    [ProducesResponseType(typeof(CashbackDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public Task<ActionResult<CashbackDecisionResponse>> Reject(
        Guid id,
        [FromBody] DecideCashbackRequest? request,
        CancellationToken cancellationToken)
    {
        return DecideAsync(
            request,
            (reviewerId, reason) => _rejectHandler.HandleAsync(
                new RejectCashbackCommand(id, reviewerId, reason), cancellationToken));
    }

    [HttpPost("api/admin/cashbacks/{id:guid}/reverse")]
    [ProducesResponseType(typeof(CashbackDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public Task<ActionResult<CashbackDecisionResponse>> Reverse(
        Guid id,
        [FromBody] DecideCashbackRequest? request,
        CancellationToken cancellationToken)
    {
        return DecideAsync(
            request,
            (reviewerId, reason) => _reverseHandler.HandleAsync(
                new ReverseCashbackCommand(id, reviewerId, reason), cancellationToken));
    }

    /// <summary>The audit trail of one cashback: network updates and admin decisions, oldest first.</summary>
    [HttpGet("api/admin/cashbacks/{id:guid}/events")]
    [ProducesResponseType(typeof(IReadOnlyList<CashbackEventResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IReadOnlyList<CashbackEventResponse>>> Events(
        Guid id,
        CancellationToken cancellationToken)
    {
        var events = await _eventsHandler.HandleAsync(
            new GetCashbackEventsQuery(id), cancellationToken);

        return events is null
            ? NotFound(new { message = "Cashback not found." })
            : Ok(events);
    }

    // A bare date or time with no zone is taken as UTC.
    private static DateTime? ToUtc(DateTime? value)
    {
        return value switch
        {
            null => null,
            { Kind: DateTimeKind.Unspecified } v => DateTime.SpecifyKind(v, DateTimeKind.Utc),
            { } v => v.ToUniversalTime()
        };
    }

    private async Task<ActionResult<CashbackDecisionResponse>> DecideAsync(
        DecideCashbackRequest? request,
        Func<Guid, string?, Task<CashbackDecisionResponse?>> decision)
    {
        // The reviewer is whoever is signed in; it is recorded with the decision.
        if (!Guid.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out Guid reviewerId))
        {
            return Unauthorized();
        }

        if (request?.Override == true && !User.IsInRole("SuperAdmin"))
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Only a SuperAdmin can approve against the network's status."
            });
        }

        string? reason = string.IsNullOrWhiteSpace(request?.Reason) ? null : request!.Reason.Trim();

        if (reason is { Length: > CashbackEvent.MaxReasonLength })
        {
            return BadRequest(new
            {
                message = $"The reason can be at most {CashbackEvent.MaxReasonLength} characters."
            });
        }

        try
        {
            var response = await decision(reviewerId, reason);

            if (response is null)
            {
                return NotFound(new { message = "Cashback not found." });
            }

            return Ok(response);
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(new { message = exception.Message });
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
    }
}
