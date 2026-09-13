using SmartMoney.Application.Features.Offers.CreateOffer;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Offers.UpdateOffer;

public sealed class UpdateOfferValidator
{
    public IReadOnlyCollection<string> Validate(UpdateOfferCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(command.Title))
        {
            errors.Add("Title is required.");
        }
        else if (command.Title.Trim().Length > 200)
        {
            errors.Add("Title must be 200 characters or fewer.");
        }

        if (string.IsNullOrWhiteSpace(command.Slug))
        {
            errors.Add("Slug is required.");
        }
        else if (command.Slug.Trim().Length > 220)
        {
            errors.Add("Slug must be 220 characters or fewer.");
        }

        if (!Enum.TryParse<OfferType>(command.OfferType, ignoreCase: true, out _))
        {
            errors.Add(
                "Offer type must be one of: " +
                string.Join(", ", Enum.GetNames<OfferType>()) + ".");
        }

        if (!Enum.TryParse<CashbackType>(command.CashbackType, ignoreCase: true, out _))
        {
            errors.Add(
                "Cashback type must be one of: " +
                string.Join(", ", Enum.GetNames<CashbackType>()) + ".");
        }

        CreateOfferValidator.ValidateDestinationUrl(command.DestinationUrl, errors);

        if (command.StartAt is DateTime start &&
            command.EndAt is DateTime end &&
            end <= start)
        {
            errors.Add("End date must be after the start date.");
        }

        return errors;
    }
}
