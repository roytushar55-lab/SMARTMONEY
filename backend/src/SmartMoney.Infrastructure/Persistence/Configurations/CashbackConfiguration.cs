using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class CashbackConfiguration : IEntityTypeConfiguration<Cashback>
{
    public void Configure(EntityTypeBuilder<Cashback> builder)
    {
        builder.ToTable("Cashbacks");

        // Optimistic concurrency (Postgres xmin): a double approve or an
        // approve racing a reverse fails with a conflict instead of both
        // succeeding. See WalletConfiguration.
        builder.Property<uint>("xmin")
            .HasColumnType("xid")
            .ValueGeneratedOnAddOrUpdate()
            .IsConcurrencyToken();

        builder.HasKey(x => x.Id);

        builder.Property(x => x.CashbackAmount)
            .HasPrecision(18, 2);

        // Stored as the enum NAME ("Pending", "AwaitingAdminReview", ...) so
        // the table is readable directly and admin tooling never has to map
        // magic numbers. Renaming an enum member is a data migration.
        builder.Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.ExpectedConfirmationDate)
            .IsRequired();

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Wallet)
            .WithMany()
            .HasForeignKey(x => x.WalletId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.AffiliateConversion)
            .WithMany()
            .HasForeignKey(x => x.AffiliateConversionId)
            .OnDelete(DeleteBehavior.Restrict);

        // One cashback per conversion — the second dedup layer behind the
        // UNIQUE(AffiliateNetworkId, NetworkTransactionId) conversion index.
        builder.HasIndex(x => x.AffiliateConversionId)
            .IsUnique();

        builder.HasIndex(x => new { x.UserId, x.Status });
    }
}
