using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;
using SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;

namespace SmartMoney.Application.Features.StoreAffiliateMappings.UpdateStoreAffiliateMapping;

/// <summary>
/// Null response = mapping not found. Store and network are immutable after
/// creation (they form the unique pair identity); only merchant metadata and
/// the active toggle can change.
/// </summary>
public sealed class UpdateStoreAffiliateMappingCommandHandler
    : ICommandHandler<UpdateStoreAffiliateMappingCommand, StoreAffiliateMappingAdminResponse?>
{
    private readonly IStoreAffiliateMappingRepository _mappingRepository;
    private readonly UpdateStoreAffiliateMappingValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateStoreAffiliateMappingCommandHandler(
        IStoreAffiliateMappingRepository mappingRepository,
        UpdateStoreAffiliateMappingValidator validator,
        IUnitOfWork unitOfWork)
    {
        _mappingRepository = mappingRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<StoreAffiliateMappingAdminResponse?> HandleAsync(
        UpdateStoreAffiliateMappingCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var mapping = await _mappingRepository.GetByIdAsync(
            command.MappingId, cancellationToken);

        if (mapping is null)
        {
            return null;
        }

        string externalMerchantId = command.ExternalMerchantId.Trim();

        if (await _mappingRepository.ExternalMerchantIdExistsAsync(
                mapping.AffiliateNetworkId, externalMerchantId, mapping.Id, cancellationToken))
        {
            throw new InvalidOperationException(
                $"External merchant id \"{externalMerchantId}\" is already used for \"{mapping.AffiliateNetwork.Name}\".");
        }

        mapping.ExternalMerchantId = externalMerchantId;
        mapping.ExternalMerchantName = command.ExternalMerchantName?.Trim();
        mapping.MerchantUrl = command.MerchantUrl?.Trim();
        mapping.IsActive = command.IsActive;
        mapping.UpdatedAt = DateTime.UtcNow;

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return CreateStoreAffiliateMappingCommandHandler.ToResponse(
            mapping, mapping.Store.Name, mapping.AffiliateNetwork.Name);
    }
}
