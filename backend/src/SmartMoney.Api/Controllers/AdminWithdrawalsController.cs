using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Application.Features.Withdrawals.AcknowledgeWithdrawal;
using SmartMoney.Application.Features.Withdrawals.ApproveWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawalSummary;
using SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;
using SmartMoney.Application.Features.Withdrawals.MarkWithdrawalFailed;
using SmartMoney.Application.Features.Withdrawals.MarkWithdrawalPaid;
using SmartMoney.Application.Features.Withdrawals.RejectWithdrawal;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Api.Controllers;

/// <summary>
/// The human half of withdrawals: review requests, pay them (manual
/// provider) or let the provider pay, and deal with anything that needs
/// attention.
/// </summary>
[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
[Route("api/admin/withdrawals")]
public sealed class AdminWithdrawalsController : ControllerBase
{
    private readonly IQueryHandler<ListAdminWithdrawalsQuery, AdminWithdrawalListResponse> _listHandler;
    private readonly IQueryHandler<GetAdminWithdrawalQuery, AdminWithdrawalResponse?> _getHandler;
    private readonly IQueryHandler<GetAdminWithdrawalSummaryQuery, AdminWithdrawalSummaryResponse> _summaryHandler;
    private readonly ICommandHandler<ApproveWithdrawalCommand, WithdrawalDecisionResponse?> _approveHandler;
    private readonly ICommandHandler<RejectWithdrawalCommand, WithdrawalDecisionResponse?> _rejectHandler;
    private readonly ICommandHandler<MarkWithdrawalPaidCommand, WithdrawalDecisionResponse?> _paidHandler;
    private readonly ICommandHandler<MarkWithdrawalFailedCommand, WithdrawalDecisionResponse?> _failedHandler;
    private readonly ICommandHandler<AcknowledgeWithdrawalCommand, WithdrawalDecisionResponse?> _acknowledgeHandler;

    public AdminWithdrawalsController(
        IQueryHandler<ListAdminWithdrawalsQuery, AdminWithdrawalListResponse> listHandler,
        IQueryHandler<GetAdminWithdrawalQuery, AdminWithdrawalResponse?> getHandler,
        IQueryHandler<GetAdminWithdrawalSummaryQuery, AdminWithdrawalSummaryResponse> summaryHandler,
        ICommandHandler<ApproveWithdrawalCommand, WithdrawalDecisionResponse?> approveHandler,
        ICommandHandler<RejectWithdrawalCommand, WithdrawalDecisionResponse?> rejectHandler,
        ICommandHandler<MarkWithdrawalPaidCommand, WithdrawalDecisionResponse?> paidHandler,
        ICommandHandler<MarkWithdrawalFailedCommand, WithdrawalDecisionResponse?> failedHandler,
        ICommandHandler<AcknowledgeWithdrawalCommand, WithdrawalDecisionResponse?> acknowledgeHandler)
    {
        _listHandler = listHandler;
        _getHandler = getHandler;
        _summaryHandler = summaryHandler;
        _approveHandler = approveHandler;
        _rejectHandler = rejectHandler;
        _paidHandler = paidHandler;
        _failedHandler = failedHandler;
        _acknowledgeHandler = acknowledgeHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(AdminWithdrawalListResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<AdminWithdrawalListResponse>> List(
        [FromQuery] string? status = null,
        [FromQuery] string? queue = null,
        [FromQuery] bool needsAttention = false,
        [FromQuery] string? search = null,
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        WithdrawalStatus? statusFilter = null;
        WithdrawalQueue? queueFilter = null;

        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!Enum.TryParse(status.Trim(), ignoreCase: true, out WithdrawalStatus parsed) ||
                !Enum.IsDefined(parsed))
            {
                return BadRequest(new
                {
                    message = "Unknown withdrawal status. Valid values: "
                        + string.Join(", ", Enum.GetNames<WithdrawalStatus>()) + "."
                });
            }

            statusFilter = parsed;
        }

        if (!string.IsNullOrWhiteSpace(queue))
        {
            if (!Enum.TryParse(queue.Trim(), ignoreCase: true, out WithdrawalQueue parsedQueue) ||
                !Enum.IsDefined(parsedQueue))
            {
                return BadRequest(new
                {
                    message = "Unknown withdrawal queue. Valid values: "
                        + string.Join(", ", Enum.GetNames<WithdrawalQueue>()) + "."
                });
            }

            queueFilter = parsedQueue;
        }

        var filter = new WithdrawalListFilter
        {
            Status = statusFilter,
            Queue = queueFilter,
            NeedsAttentionOnly = needsAttention,
            Search = search,
            CreatedFrom = ToUtc(from),
            CreatedBefore = ToUtc(to)
        };

        var response = await _listHandler.HandleAsync(
            new ListAdminWithdrawalsQuery(filter, page, pageSize),
            cancellationToken);

        return Ok(response);
    }

    /// <summary>
    /// The numbers on top of the page: how many are in each queue, the rupees
    /// waiting to be decided and paid, how many need attention, and what was
    /// paid in the last 30 days.
    /// </summary>
    [HttpGet("summary")]
    [ProducesResponseType(typeof(AdminWithdrawalSummaryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<AdminWithdrawalSummaryResponse>> Summary(
        CancellationToken cancellationToken)
    {
        var response = await _summaryHandler.HandleAsync(
            new GetAdminWithdrawalSummaryQuery(), cancellationToken);

        return Ok(response);
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

    /// <summary>
    /// Includes the full bank or UPI details while the withdrawal is open,
    /// so the response must never be cached.
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(AdminWithdrawalResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<AdminWithdrawalResponse>> Get(
        Guid id,
        CancellationToken cancellationToken)
    {
        var response = await _getHandler.HandleAsync(
            new GetAdminWithdrawalQuery(id), cancellationToken);

        if (response is null)
        {
            return NotFound(new { message = "Withdrawal not found." });
        }

        Response.Headers.CacheControl = "no-store";

        return Ok(response);
    }

    [HttpPost("{id:guid}/approve")]
    [ProducesResponseType(typeof(WithdrawalDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public Task<ActionResult<WithdrawalDecisionResponse>> Approve(
        Guid id,
        CancellationToken cancellationToken)
    {
        return DecideAsync(reviewerId =>
            _approveHandler.HandleAsync(
                new ApproveWithdrawalCommand(id, reviewerId), cancellationToken));
    }

    /// <summary>Declines it. The reason is shown to the user.</summary>
    [HttpPost("{id:guid}/reject")]
    [ProducesResponseType(typeof(WithdrawalDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public Task<ActionResult<WithdrawalDecisionResponse>> Reject(
        Guid id,
        [FromBody] RejectWithdrawalRequest request,
        CancellationToken cancellationToken)
    {
        return DecideAsync(reviewerId =>
            _rejectHandler.HandleAsync(
                new RejectWithdrawalCommand(id, reviewerId, request.Reason), cancellationToken));
    }

    /// <summary>Records that the user was paid outside the system.</summary>
    [HttpPost("{id:guid}/mark-paid")]
    [ProducesResponseType(typeof(WithdrawalDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public Task<ActionResult<WithdrawalDecisionResponse>> MarkPaid(
        Guid id,
        [FromBody] MarkWithdrawalPaidRequest request,
        CancellationToken cancellationToken)
    {
        return DecideAsync(reviewerId =>
            _paidHandler.HandleAsync(
                new MarkWithdrawalPaidCommand(id, reviewerId, request.TransactionReference),
                cancellationToken));
    }

    /// <summary>Records that an approved payout could not be made. The reason is shown to the user.</summary>
    [HttpPost("{id:guid}/mark-failed")]
    [ProducesResponseType(typeof(WithdrawalDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public Task<ActionResult<WithdrawalDecisionResponse>> MarkFailed(
        Guid id,
        [FromBody] MarkWithdrawalFailedRequest request,
        CancellationToken cancellationToken)
    {
        return DecideAsync(_ =>
            _failedHandler.HandleAsync(
                new MarkWithdrawalFailedCommand(id, request.Reason), cancellationToken));
    }

    /// <summary>Clears the needs-attention flag once an admin has dealt with it. Moves no money.</summary>
    [HttpPost("{id:guid}/acknowledge")]
    [ProducesResponseType(typeof(WithdrawalDecisionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public Task<ActionResult<WithdrawalDecisionResponse>> Acknowledge(
        Guid id,
        CancellationToken cancellationToken)
    {
        return DecideAsync(_ =>
            _acknowledgeHandler.HandleAsync(
                new AcknowledgeWithdrawalCommand(id), cancellationToken));
    }

    private async Task<ActionResult<WithdrawalDecisionResponse>> DecideAsync(
        Func<Guid, Task<WithdrawalDecisionResponse?>> decision)
    {
        if (!Guid.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out Guid reviewerId))
        {
            return Unauthorized();
        }

        try
        {
            var response = await decision(reviewerId);

            if (response is null)
            {
                return NotFound(new { message = "Withdrawal not found." });
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
