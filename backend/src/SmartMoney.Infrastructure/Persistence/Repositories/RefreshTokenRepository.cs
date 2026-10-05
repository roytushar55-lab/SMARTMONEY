using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class RefreshTokenRepository : IRefreshTokenRepository
{
    private readonly SmartMoneyDbContext _context;

    public RefreshTokenRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public Task<RefreshToken?> GetByTokenAsync(
        string token,
        CancellationToken cancellationToken = default)
    {
        string tokenHash = RefreshToken.HashToken(token);

        return _context.RefreshTokens
            .Include(refreshToken => refreshToken.User)
            .ThenInclude(user => user.Role)
            .SingleOrDefaultAsync(
                refreshToken => refreshToken.Token == tokenHash,
                cancellationToken);
    }

    public async Task AddAsync(
        RefreshToken refreshToken,
        CancellationToken cancellationToken = default)
    {
        await _context.RefreshTokens.AddAsync(refreshToken, cancellationToken);
    }

    public async Task RevokeAllForUserAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var tokens = await _context.RefreshTokens
            .Where(refreshToken => refreshToken.UserId == userId && !refreshToken.IsRevoked)
            .ToListAsync(cancellationToken);

        foreach (var token in tokens)
        {
            token.Revoke();
        }
    }
}
