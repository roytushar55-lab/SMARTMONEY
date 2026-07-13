using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class WalletRepository : IWalletRepository
{
    private readonly SmartMoneyDbContext _context;

    public WalletRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(
        Wallet wallet,
        CancellationToken cancellationToken = default)
    {
        await _context.Wallets.AddAsync(wallet, cancellationToken);
    }
}