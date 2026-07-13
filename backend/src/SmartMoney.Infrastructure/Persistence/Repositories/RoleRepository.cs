using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class RoleRepository : IRoleRepository
{
    private readonly SmartMoneyDbContext _context;

    public RoleRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task<Role?> GetByNameAsync(
        RoleType roleType,
        CancellationToken cancellationToken = default)
    {
        return await _context.Roles
            .FirstOrDefaultAsync(
                x => x.Name == roleType,
                cancellationToken);
    }
}