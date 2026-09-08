using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.AffiliateNetworks;
using SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;

namespace SmartMoney.Application.Features.AffiliateNetworks.UpdateAffiliateNetwork;

/// <summary>
/// Null response = network not found. Deactivating a network here does not
/// touch existing StoreAffiliateMappings — pause those separately if needed.
/// </summary>
public sealed class UpdateAffiliateNetworkCommandHandler
    : ICommandHandler<UpdateAffiliateNetworkCommand, AffiliateNetworkAdminResponse?>
{
    private readonly IAffiliateNetworkRepository _networkRepository;
    private readonly UpdateAffiliateNetworkValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateAffiliateNetworkCommandHandler(
        IAffiliateNetworkRepository networkRepository,
        UpdateAffiliateNetworkValidator validator,
        IUnitOfWork unitOfWork)
    {
        _networkRepository = networkRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<AffiliateNetworkAdminResponse?> HandleAsync(
        UpdateAffiliateNetworkCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        var network = await _networkRepository.GetByIdAsync(
            command.NetworkId, cancellationToken);

        if (network is null)
        {
            return null;
        }

        string name = command.Name.Trim();
        string code = command.Code.Trim().ToUpperInvariant();

        if (await _networkRepository.NameExistsAsync(name, network.Id, cancellationToken))
        {
            throw new InvalidOperationException($"A network named \"{name}\" already exists.");
        }

        if (await _networkRepository.CodeExistsAsync(code, network.Id, cancellationToken))
        {
            throw new InvalidOperationException($"The code \"{code}\" is already in use.");
        }

        network.Name = name;
        network.Code = code;
        network.IsActive = command.IsActive;
        network.UpdatedAt = DateTime.UtcNow;

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return CreateAffiliateNetworkCommandHandler.ToResponse(network);
    }
}
