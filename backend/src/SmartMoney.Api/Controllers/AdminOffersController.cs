using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Offers;
using SmartMoney.Application.Features.Offers.CreateOffer;
using SmartMoney.Application.Features.Offers.ListOffersAdmin;
using SmartMoney.Application.Features.Offers.UpdateOffer;

namespace SmartMoney.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin,SuperAdmin")]
[Route("api/admin/offers")]
public sealed class AdminOffersController : ControllerBase
{
    private readonly IQueryHandler<ListOffersAdminQuery, IReadOnlyList<OfferAdminResponse>> _listHandler;
    private readonly ICommandHandler<CreateOfferCommand, OfferAdminResponse?> _createHandler;
    private readonly ICommandHandler<UpdateOfferCommand, OfferAdminResponse?> _updateHandler;

    public AdminOffersController(
        IQueryHandler<ListOffersAdminQuery, IReadOnlyList<OfferAdminResponse>> listHandler,
        ICommandHandler<CreateOfferCommand, OfferAdminResponse?> createHandler,
        ICommandHandler<UpdateOfferCommand, OfferAdminResponse?> updateHandler)
    {
        _listHandler = listHandler;
        _createHandler = createHandler;
        _updateHandler = updateHandler;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<OfferAdminResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<OfferAdminResponse>>> List(
        [FromQuery] Guid? storeId,
        CancellationToken cancellationToken)
    {
        var offers = await _listHandler.HandleAsync(
            new ListOffersAdminQuery(storeId), cancellationToken);

        return Ok(offers);
    }

    [HttpPost]
    [ProducesResponseType(typeof(OfferAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<OfferAdminResponse>> Create(
        [FromBody] CreateOfferRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateOfferCommand(
            request.StoreId,
            request.Title,
            request.Slug,
            request.OfferType,
            request.ShortDescription,
            request.Description,
            request.TermsAndConditions,
            request.ImageUrl,
            request.CashbackType,
            request.CashbackValue,
            request.CashbackText,
            request.CouponCode,
            request.DestinationUrl,
            request.StartAt,
            request.EndAt,
            request.IsFeatured,
            request.Priority);

        try
        {
            var offer = await _createHandler.HandleAsync(command, cancellationToken);

            if (offer is null)
            {
                return NotFound(new { message = "Store not found." });
            }

            return Ok(offer);
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
    [ProducesResponseType(typeof(OfferAdminResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<OfferAdminResponse>> Update(
        Guid id,
        [FromBody] UpdateOfferRequest request,
        CancellationToken cancellationToken)
    {
        var command = new UpdateOfferCommand(
            id,
            request.Title,
            request.Slug,
            request.OfferType,
            request.ShortDescription,
            request.Description,
            request.TermsAndConditions,
            request.ImageUrl,
            request.CashbackType,
            request.CashbackValue,
            request.CashbackText,
            request.CouponCode,
            request.DestinationUrl,
            request.StartAt,
            request.EndAt,
            request.IsFeatured,
            request.Priority,
            request.IsActive);

        try
        {
            var offer = await _updateHandler.HandleAsync(command, cancellationToken);

            if (offer is null)
            {
                return NotFound(new { message = "Offer not found." });
            }

            return Ok(offer);
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
