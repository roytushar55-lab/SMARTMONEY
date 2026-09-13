using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.AffiliateNetworks;

namespace SmartMoney.Application.Features.AffiliateNetworks.UpdateAffiliateNetwork;

public sealed class UpdateAffiliateNetworkCommand : ICommand<AffiliateNetworkAdminResponse?>
{
    public Guid NetworkId { get; }

    public string Name { get; }

    public string Code { get; }

    public bool IsActive { get; }

    public UpdateAffiliateNetworkCommand(Guid networkId, string name, string code, bool isActive)
    {
        NetworkId = networkId;
        Name = name;
        Code = code;
        IsActive = isActive;
    }
}
