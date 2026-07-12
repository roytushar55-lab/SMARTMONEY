using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class WalletConfiguration : IEntityTypeConfiguration<Wallet>
{
    public void Configure(EntityTypeBuilder<Wallet> builder)
    {
        builder.ToTable("Wallets");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.AvailableBalance)
            .HasPrecision(18, 2);

        builder.Property(x => x.PendingBalance)
            .HasPrecision(18, 2);

        builder.Property(x => x.TotalEarned)
            .HasPrecision(18, 2);

        builder.Property(x => x.TotalWithdrawn)
            .HasPrecision(18, 2);

        builder.HasOne(x => x.User)
            .WithOne()
            .HasForeignKey<Wallet>(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}