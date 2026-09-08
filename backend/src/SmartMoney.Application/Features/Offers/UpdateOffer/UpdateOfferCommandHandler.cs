using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Offers;
using SmartMoney.Application.Features.Offers.CreateOffer;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Offers.UpdateOffer;

/// <summary>Null response = offer not found. Also the activate/deactivate toggle.</summary>
public sealed class UpdateOfferCommandHandler
    : ICommandHandler<UpdateOfferCommand, OfferAdminResponse?>
{
    private readonly IOfferRepository _offerRepository;
    private readonly UpdateOfferValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateOfferCommandHandler(
        IOfferRepository offerRepository,
        UpdateOfferValidator validator,
        IUnitOfWork unitOfWork)
    {
        _offerRepository = offerRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<OfferAdminResponse?> HandleAsync(
        UpdateOfferCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var offer = await _offerRepository.GetByIdAsync(command.OfferId, cancellationToken);

        if (offer is null)
        {
            return null;
        }

        string slug = command.Slug.Trim().ToLowerInvariant();

        if (await _offerRepository.SlugExistsAsync(slug, offer.Id, cancellationToken))
        {
            throw new InvalidOperationException($"The slug \"{slug}\" is already in use.");
        }

        offer.Title = command.Title.Trim();
        offer.Slug = slug;
        offer.OfferType = Enum.Parse<OfferType>(command.OfferType, ignoreCase: true);
        offer.ShortDescription = command.ShortDescription?.Trim();
        offer.Description = command.Description?.Trim();
        offer.TermsAndConditions = command.TermsAndConditions?.Trim();
        offer.ImageUrl = command.ImageUrl?.Trim();
        offer.CashbackType = Enum.Parse<CashbackType>(command.CashbackType, ignoreCase: true);
        offer.CashbackValue = command.CashbackValue;
        offer.CashbackText = command.CashbackText?.Trim();
        offer.CouponCode = command.CouponCode?.Trim();
        offer.DestinationUrl = command.DestinationUrl.Trim();
        offer.StartAt = command.StartAt;
        offer.EndAt = command.EndAt;
        offer.IsFeatured = command.IsFeatured;
        offer.Priority = command.Priority;
        offer.IsActive = command.IsActive;
        offer.UpdatedAt = DateTime.UtcNow;

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return CreateOfferCommandHandler.ToResponse(offer, offer.Store.Name);
    }
}
