using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class WalletConfiguration : IEntityTypeConfiguration<Wallet>
{
    public void Configure(EntityTypeBuilder<Wallet> builder)
    {
        builder.ToTable("Wallets", table =>
        {
            // Last line of defence: no code path may ever leave a wallet
            // with negative money, whatever a handler does.
            table.HasCheckConstraint(
                "CK_Wallets_BalancesNonNegative",
                "\"AvailableBalance\" >= 0 AND \"PendingBalance\" >= 0");
        });

        // Postgres xmin as an optimistic-concurrency token: two requests that
        // read the same wallet cannot both write it (the second gets a
        // concurrency conflict instead of silently overwriting the first).
        builder.Property<uint>("xmin")
            .HasColumnType("xid")
            .ValueGeneratedOnAddOrUpdate()
            .IsConcurrencyToken();

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