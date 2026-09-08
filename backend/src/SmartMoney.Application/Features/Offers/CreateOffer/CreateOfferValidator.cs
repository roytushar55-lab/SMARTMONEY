using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Offers.CreateOffer;

public sealed class CreateOfferValidator
{
    public IReadOnlyCollection<string> Validate(CreateOfferCommand command)
    {
        ArgumentNullException.ThrowIfNull(command);

        var errors = new List<string>();

        if (command.StoreId == Guid.Empty)
        {
            errors.Add("A store is required.");
        }

        if (string.IsNullOrWhiteSpace(command.Title))
        {
            errors.Add("Title is required.");
        }
        else if (command.Title.Trim().Length > 200)
        {
            errors.Add("Title must be 200 characters or fewer.");
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

        ValidateDestinationUrl(command.DestinationUrl, errors);

        if (command.StartAt is DateTime start &&
            command.EndAt is DateTime end &&
            end <= start)
        {
            errors.Add("End date must be after the start date.");
        }

        return errors;
    }

    internal static void ValidateDestinationUrl(string destinationUrl, ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(destinationUrl))
        {
            errors.Add("Destination URL is required.");
            return;
        }

        if (!Uri.TryCreate(destinationUrl, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            errors.Add("Destination URL must be a valid http(s) URL.");
        }
    }
}
