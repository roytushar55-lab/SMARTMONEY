using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.Affiliate;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;

public sealed class IngestAffiliateConversionCommandHandler
    : ICommandHandler<IngestAffiliateConversionCommand, IngestAffiliateConversionResponse>
{
    private const string OutcomeCreated = "Created";
    private const string OutcomeUpdated = "Updated";

    private readonly IngestAffiliateConversionValidator _validator;
    private readonly IAffiliateNetworkRepository _networkRepository;
    private readonly IAffiliateConversionRepository _conversionRepository;
    private readonly IAffiliateClickRepository _clickRepository;
    private readonly ConversionCashbackProcessor _cashbackProcessor;
    private readonly IUnitOfWork _unitOfWork;

    public IngestAffiliateConversionCommandHandler(
        IngestAffiliateConversionValidator validator,
        IAffiliateNetworkRepository networkRepository,
        IAffiliateConversionRepository conversionRepository,
        IAffiliateClickRepository clickRepository,
        ConversionCashbackProcessor cashbackProcessor,
        IUnitOfWork unitOfWork)
    {
        _validator = validator;
        _networkRepository = networkRepository;
        _conversionRepository = conversionRepository;
        _clickRepository = clickRepository;
        _cashbackProcessor = cashbackProcessor;
        _unitOfWork = unitOfWork;
    }

    public async Task<IngestAffiliateConversionResponse> HandleAsync(
        IngestAffiliateConversionCommand command,
        CancellationToken cancellationToken)
    {
        var validationErrors = _validator.Validate(command);

        if (validationErrors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", validationErrors));
        }

        // Provider identifiers are stored verbatim apart from trimming;
        // network codes are stored uppercase by convention.
        var networkCode = command.NetworkCode.Trim().ToUpperInvariant();
        var networkTransactionId = command.NetworkTransactionId.Trim();
        var trackingReference = NormalizeOptional(command.TrackingReference);
        var networkStatus = command.NetworkStatus.Trim();
        var currency = NormalizeOptional(command.Currency);
        var transactionOccurredAt = NormalizeUtc(command.TransactionOccurredAt);
        var networkUpdatedAt = NormalizeUtc(command.NetworkUpdatedAt);

        var network = await _networkRepository.GetByCodeAsync(networkCode, cancellationToken);

        if (network is null)
        {
            throw new InvalidOperationException("Unknown affiliate network.");
        }

        var conversion = await _conversionRepository.GetByNetworkAndTransactionIdAsync(
            network.Id, networkTransactionId, cancellationToken);

        var isNew = conversion is null;

        if (conversion is null)
        {
            conversion = new AffiliateConversion
            {
                AffiliateNetworkId = network.Id,
                NetworkTransactionId = networkTransactionId,
            };
        }

        // What the network said last time, for the cashback audit trail.
        string? previousNetworkStatus = isNew ? null : conversion.NetworkStatus;

        // Snapshot fields: the provider's latest report is authoritative,
        // including explicit nulls (e.g. an amount removed on reversal).
        // A staleness guard on NetworkUpdatedAt (skip out-of-order postbacks)
        // is deferred until real provider ordering semantics are known.
        conversion.NetworkStatus = networkStatus;
        conversion.OrderAmount = command.OrderAmount;
        conversion.CommissionAmount = command.CommissionAmount;
        conversion.Currency = currency;
        conversion.TransactionOccurredAt = transactionOccurredAt;
        conversion.NetworkUpdatedAt = networkUpdatedAt;

        // Continuity fields: an absent value never erases what we already
        // hold — the stored reference is the attribution-retry input and the
        // stored payload is the only raw record.
        if (command.RawPayload is not null)
        {
            conversion.RawPayload = command.RawPayload;
        }

        // Once attributed, both the click link and the reference that
        // produced it are frozen; provider updates never re-point history.
        if (conversion.AffiliateClickId is null)
        {
            if (trackingReference is not null)
            {
                conversion.TrackingReference = trackingReference;
            }

            if (conversion.TrackingReference is not null)
            {
                var click = await _clickRepository.GetByTrackingReferenceAsync(
                    conversion.TrackingReference, cancellationToken);

                if (click is not null && click.AffiliateNetworkId == network.Id)
                {
                    conversion.AffiliateClickId = click.Id;
                }
            }
        }

        if (isNew)
        {
            await _conversionRepository.AddAsync(conversion, cancellationToken);
        }
        else
        {
            conversion.UpdatedAt = DateTime.UtcNow;
        }

        // Before SaveChanges so the cashback creation/transition commits
        // atomically with the conversion it derives from.
        await _cashbackProcessor.ProcessAsync(
            conversion, cancellationToken, previousNetworkStatus);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new IngestAffiliateConversionResponse(
            conversion.Id,
            isNew ? OutcomeCreated : OutcomeUpdated,
            conversion.AffiliateClickId is not null,
            conversion.AffiliateClickId);
    }

    private static string? NormalizeOptional(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    // timestamptz columns require Kind=Utc. Providers are assumed to report
    // UTC when no offset is given.
    private static DateTime? NormalizeUtc(DateTime? value)
    {
        if (value is not DateTime dateTime)
        {
            return null;
        }

        return dateTime.Kind switch
        {
            DateTimeKind.Utc => dateTime,
            DateTimeKind.Local => dateTime.ToUniversalTime(),
            _ => DateTime.SpecifyKind(dateTime, DateTimeKind.Utc),
        };
    }
}
