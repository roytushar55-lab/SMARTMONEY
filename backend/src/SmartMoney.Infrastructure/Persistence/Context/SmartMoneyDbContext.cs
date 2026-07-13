using Microsoft.EntityFrameworkCore;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Context;

public sealed class SmartMoneyDbContext : DbContext
{
    public SmartMoneyDbContext(DbContextOptions<SmartMoneyDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();

    public DbSet<Role> Roles => Set<Role>();

    public DbSet<Wallet> Wallets => Set<Wallet>();

    public DbSet<Cashback> Cashbacks => Set<Cashback>();

    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.ApplyConfigurationsFromAssembly(typeof(SmartMoneyDbContext).Assembly);
    }
}