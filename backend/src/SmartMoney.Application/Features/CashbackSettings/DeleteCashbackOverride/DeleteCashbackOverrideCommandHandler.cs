using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Abstractions.Persistence;

namespace SmartMoney.Application.Features.CashbackSettings.DeleteCashbackOverride;

/// <summary>False = the override does not exist, or belongs to a different network.</summary>
public sealed class DeleteCashbackOverrideCommandHandler
    : ICommandHandler<DeleteCashbackOverrideCommand, bool>
{
    private readonly ICashbackRateOverrideRepository _overrideRepository;
    private readonly IUnitOfWork _unitOfWork;

    public DeleteCashbackOverrideCommandHandler(
        ICashbackRateOverrideRepository overrideRepository,
        IUnitOfWork unitOfWork)
    {
        _overrideRepository = overrideRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<bool> HandleAsync(
        DeleteCashbackOverrideCommand command,
        CancellationToken cancellationToken)
    {
        var @override = await _overrideRepository.GetByIdAsync(command.OverrideId, cancellationToken);

        if (@override is null || @override.AffiliateNetworkId != command.AffiliateNetworkId)
        {
            return false;
        }

        _overrideRepository.Remove(@override);

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return true;
    }
}
