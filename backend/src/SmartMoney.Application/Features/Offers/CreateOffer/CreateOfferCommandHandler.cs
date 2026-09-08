using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Common;
using SmartMoney.Application.Contracts.Offers;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Offers.CreateOffer;

/// <summary>Null response = the target store does not exist.</summary>
public sealed class CreateOfferCommandHandler
    : ICommandHandler<CreateOfferCommand, OfferAdminResponse?>
{
    private readonly IOfferRepository _offerRepository;
    private readonly IStoreRepository _storeRepository;
    private readonly CreateOfferValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public CreateOfferCommandHandler(
        IOfferRepository offerRepository,
        IStoreRepository storeRepository,
        CreateOfferValidator validator,
        IUnitOfWork unitOfWork)
    {
        _offerRepository = offerRepository;
        _storeRepository = storeRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<OfferAdminResponse?> HandleAsync(
        CreateOfferCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var store = await _storeRepository.GetByIdAsync(command.StoreId, cancellationToken);

        if (store is null)
        {
            return null;
        }

        string title = command.Title.Trim();
        string slug = string.IsNullOrWhiteSpace(command.Slug)
            ? SlugGenerator.Generate(title)
            : command.Slug.Trim().ToLowerInvariant();

        if (string.IsNullOrEmpty(slug))
        {
            throw new ArgumentException("A usable slug could not be generated from the title.");
        }

        if (await _offerRepository.SlugExistsAsync(slug, null, cancellationToken))
        {
            throw new InvalidOperationException($"The slug \"{slug}\" is already in use.");
        }

        var offer = new Offer
        {
            StoreId = store.Id,
            Title = title,
            Slug = slug,
            OfferType = Enum.Parse<OfferType>(command.OfferType, ignoreCase: true),
            ShortDescription = command.ShortDescription?.Trim(),
            Description = command.Description?.Trim(),
            TermsAndConditions = command.TermsAndConditions?.Trim(),
            ImageUrl = command.ImageUrl?.Trim(),
            CashbackType = Enum.Parse<CashbackType>(command.CashbackType, ignoreCase: true),
            CashbackValue = command.CashbackValue,
            CashbackText = command.CashbackText?.Trim(),
            CouponCode = command.CouponCode?.Trim(),
            DestinationUrl = command.DestinationUrl.Trim(),
            StartAt = command.StartAt,
            EndAt = command.EndAt,
            IsFeatured = command.IsFeatured,
            Priority = command.Priority
        };

        await _offerRepository.AddAsync(offer, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return ToResponse(offer, store.Name);
    }

    internal static OfferAdminResponse ToResponse(Offer offer, string storeName)
    {
        return new OfferAdminResponse
        {
            Id = offer.Id,
            StoreId = offer.StoreId,
            StoreName = storeName,
            Title = offer.Title,
            Slug = offer.Slug,
            OfferType = offer.OfferType.ToString(),
            ShortDescription = offer.ShortDescription,
            Description = offer.Description,
            TermsAndConditions = offer.TermsAndConditions,
            ImageUrl = offer.ImageUrl,
            CashbackType = offer.CashbackType.ToString(),
            CashbackValue = offer.CashbackValue,
            CashbackText = offer.CashbackText,
            CouponCode = offer.CouponCode,
            DestinationUrl = offer.DestinationUrl,
            StartAt = offer.StartAt,
            EndAt = offer.EndAt,
            IsFeatured = offer.IsFeatured,
            Priority = offer.Priority,
            IsActive = offer.IsActive,
            CreatedAt = offer.CreatedAt,
            UpdatedAt = offer.UpdatedAt
        };
    }
}
