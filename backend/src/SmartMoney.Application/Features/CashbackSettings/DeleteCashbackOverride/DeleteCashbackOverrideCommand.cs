using SmartMoney.Application.Abstractions.Messaging;

namespace SmartMoney.Application.Features.CashbackSettings.DeleteCashbackOverride;

public sealed class DeleteCashbackOverrideCommand : ICommand<bool>
{
    public Guid AffiliateNetworkId { get; }

    public Guid OverrideId { get; }

    public DeleteCashbackOverrideCommand(Guid affiliateNetworkId, Guid overrideId)
    {
        AffiliateNetworkId = affiliateNetworkId;
        OverrideId = overrideId;
    }
}
