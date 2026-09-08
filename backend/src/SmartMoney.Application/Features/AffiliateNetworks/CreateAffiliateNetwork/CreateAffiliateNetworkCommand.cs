using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.AffiliateNetworks;

namespace SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;

public sealed class CreateAffiliateNetworkCommand : ICommand<AffiliateNetworkAdminResponse>
{
    public string Name { get; }

    public string Code { get; }

    public CreateAffiliateNetworkCommand(string name, string code)
    {
        Name = name;
        Code = code;
    }
}
