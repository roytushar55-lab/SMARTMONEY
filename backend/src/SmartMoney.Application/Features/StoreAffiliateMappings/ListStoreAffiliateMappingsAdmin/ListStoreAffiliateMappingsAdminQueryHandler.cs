using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;
using SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;

namespace SmartMoney.Application.Features.StoreAffiliateMappings.ListStoreAffiliateMappingsAdmin;

public sealed class ListStoreAffiliateMappingsAdminQueryHandler
    : IQueryHandler<ListStoreAffiliateMappingsAdminQuery, IReadOnlyList<StoreAffiliateMappingAdminResponse>>
{
    private readonly IStoreAffiliateMappingRepository _mappingRepository;

    public ListStoreAffiliateMappingsAdminQueryHandler(
        IStoreAffiliateMappingRepository mappingRepository)
    {
        _mappingRepository = mappingRepository;
    }

    public async Task<IReadOnlyList<StoreAffiliateMappingAdminResponse>> HandleAsync(
        ListStoreAffiliateMappingsAdminQuery query,
        CancellationToken cancellationToken)
    {
        var mappings = await _mappingRepository.GetAllAsync(query.StoreId, cancellationToken);

        return mappings
            .Select(mapping => CreateStoreAffiliateMappingCommandHandler.ToResponse(
                mapping, mapping.Store.Name, mapping.AffiliateNetwork.Name))
            .ToList();
    }
}
