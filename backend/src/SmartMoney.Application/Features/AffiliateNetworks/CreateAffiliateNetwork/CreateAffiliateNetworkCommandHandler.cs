using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Contracts.AffiliateNetworks;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;

/// <summary>
/// SuperAdmin-only: registers a new affiliate provider (e.g. Admitad
/// alongside Cuelinks). Code must match what the provider's webhooks send
/// so <c>WebhooksController</c> can resolve it — this is what replaces the
/// manual affiliate-seed.sql insert.
/// </summary>
public sealed class CreateAffiliateNetworkCommandHandler
    : ICommandHandler<CreateAffiliateNetworkCommand, AffiliateNetworkAdminResponse>
{
    private readonly IAffiliateNetworkRepository _networkRepository;
    private readonly CreateAffiliateNetworkValidator _validator;
    private readonly IUnitOfWork _unitOfWork;

    public CreateAffiliateNetworkCommandHandler(
        IAffiliateNetworkRepository networkRepository,
        CreateAffiliateNetworkValidator validator,
        IUnitOfWork unitOfWork)
    {
        _networkRepository = networkRepository;
        _validator = validator;
        _unitOfWork = unitOfWork;
    }

    public async Task<AffiliateNetworkAdminResponse> HandleAsync(
        CreateAffiliateNetworkCommand command,
        CancellationToken cancellationToken)
    {
        var errors = _validator.Validate(command);

        if (errors.Count > 0)
        {
            throw new ArgumentException(string.Join(" ", errors));
        }

        string name = command.Name.Trim();
        string code = command.Code.Trim().ToUpperInvariant();

        if (await _networkRepository.NameExistsAsync(name, null, cancellationToken))
        {
            throw new InvalidOperationException($"A network named \"{name}\" already exists.");
        }

        if (await _networkRepository.CodeExistsAsync(code, null, cancellationToken))
        {
            throw new InvalidOperationException($"The code \"{code}\" is already in use.");
        }

        var network = new AffiliateNetwork
        {
            Name = name,
            Code = code
        };

        await _networkRepository.AddAsync(network, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return ToResponse(network);
    }

    internal static AffiliateNetworkAdminResponse ToResponse(AffiliateNetwork network)
    {
        return new AffiliateNetworkAdminResponse
        {
            Id = network.Id,
            Name = network.Name,
            Code = network.Code,
            IsActive = network.IsActive,
            CreatedAt = network.CreatedAt,
            UpdatedAt = network.UpdatedAt
        };
    }
}
