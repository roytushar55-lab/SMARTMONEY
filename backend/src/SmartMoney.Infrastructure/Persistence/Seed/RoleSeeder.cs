using Microsoft.EntityFrameworkCore;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Seed;

public static class RoleSeeder
{
    public static async Task SeedAsync(SmartMoneyDbContext context)
    {
        var roles = new[]
        {
            new Role(RoleType.Customer, "Default customer"),
            new Role(RoleType.Admin, "System administrator"),
            new Role(RoleType.SuperAdmin, "Super administrator"),
            new Role(RoleType.Support, "Customer support"),
            new Role(RoleType.Finance, "Finance team")
        };

        foreach (var role in roles)
        {
            var exists = await context.Roles
                .AnyAsync(existingRole => existingRole.Name == role.Name);

            if (!exists)
            {
                await context.Roles.AddAsync(role);
            }
        }

        await context.SaveChangesAsync();
    }
}