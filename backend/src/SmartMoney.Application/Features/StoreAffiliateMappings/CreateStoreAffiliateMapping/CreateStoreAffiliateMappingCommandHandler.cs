using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;

/// <summary>
/// SuperAdmin-only: links a store to a network's own merchant id, replacing
/// the manual StoreAffiliateMappings insert in affiliate-seed.sql. This is
/// what a click actually needs (via MockAffiliateNetworkClient /
/// CuelinksAffiliateNetworkClient) before it can earn commission at all.
/// Null response = store or network not found.
/// </summary>
public sealed class CreateStoreAffiliateMappingCommandHandler
    : ICommandHandler<CreateStoreAffiliateMappingCommand, StoreAffiliateMappingAdminResponse?>
{
    private readonly IStoreAffiliateMappingRepository _mappingRepository;
    private readonly IStoreRepository _storeRepository;
    private readonly IAffiliateNetworkRepository _networkRepository;
    private readonly CreateStoreAffiliateMappingValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public CreateStoreAffiliateMappingCommandHandler(
        IStoreAffiliateMappingRepository mappingRepository,
        IStoreRepository storeRepository,
        IAffiliateNetworkRepository networkRepository,
        CreateStoreAffiliateMappingValidator validator,
        IUnitOfWork unitOfWork)
    {
        _mappingRepository = mappingRepository;
        _storeRepository = storeRepository;
        _networkRepository = networkRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<StoreAffiliateMappingAdminResponse?> HandleAsync(
        CreateStoreAffiliateMappingCommand command,
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

        var network = await _networkRepository.GetByIdAsync(
            command.AffiliateNetworkId, cancellationToken);

        if (network is null)
        {
            return null;
        }

        if (await _mappingRepository.StoreNetworkPairExistsAsync(
                store.Id, network.Id, null, cancellationToken))
        {
            throw new InvalidOperationException(
                $"\"{store.Name}\" is already mapped to \"{network.Name}\".");
        }

        string externalMerchantId = command.ExternalMerchantId.Trim();

        if (await _mappingRepository.ExternalMerchantIdExistsAsync(
                network.Id, externalMerchantId, null, cancellationToken))
        {
            throw new InvalidOperationException(
                $"External merchant id \"{externalMerchantId}\" is already used for \"{network.Name}\".");
        }

        var mapping = new StoreAffiliateMapping
        {
            StoreId = store.Id,
            AffiliateNetworkId = network.Id,
            ExternalMerchantId = externalMerchantId,
            ExternalMerchantName = command.ExternalMerchantName?.Trim(),
            MerchantUrl = command.MerchantUrl?.Trim()
        };

        await _mappingRepository.AddAsync(mapping, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return ToResponse(mapping, store.Name, network.Name);
    }

    internal static StoreAffiliateMappingAdminResponse ToResponse(
        StoreAffiliateMapping mapping, string storeName, string networkName)
    {
        return new StoreAffiliateMappingAdminResponse
        {
            Id = mapping.Id,
            StoreId = mapping.StoreId,
            StoreName = storeName,
            AffiliateNetworkId = mapping.AffiliateNetworkId,
            AffiliateNetworkName = networkName,
            ExternalMerchantId = mapping.ExternalMerchantId,
            ExternalMerchantName = mapping.ExternalMerchantName,
            MerchantUrl = mapping.MerchantUrl,
            IsActive = mapping.IsActive,
            LastSyncedAt = mapping.LastSyncedAt,
            CreatedAt = mapping.CreatedAt,
            UpdatedAt = mapping.UpdatedAt
        };
    }
}
