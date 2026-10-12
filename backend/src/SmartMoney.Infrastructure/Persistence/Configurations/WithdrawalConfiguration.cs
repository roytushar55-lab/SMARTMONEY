using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class WithdrawalConfiguration : IEntityTypeConfiguration<Withdrawal>
{
    public void Configure(EntityTypeBuilder<Withdrawal> builder)
    {
        builder.ToTable("Withdrawals", table =>
        {
            // Last line of defence behind the entity's own validation.
            table.HasCheckConstraint(
                "CK_Withdrawals_AmountsValid",
                "\"Amount\" > 0 AND \"NetAmount\" > 0 AND \"FeeTotal\" >= 0 " +
                "AND \"UserFee\" >= 0 AND \"UserFee\" <= \"FeeTotal\"");
        });

        // Optimistic concurrency (Postgres xmin): an admin approving while the
        // user cancels, or a webhook racing the worker, fails with a conflict
        // instead of both succeeding. See WalletConfiguration.
        builder.Property<uint>("xmin")
            .HasColumnType("xid")
            .ValueGeneratedOnAddOrUpdate()
            .IsConcurrencyToken();

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Reference)
            .HasMaxLength(40)
            .IsRequired();

        builder.Property(x => x.Amount).HasPrecision(18, 2);
        builder.Property(x => x.FeeTotal).HasPrecision(18, 2);
        builder.Property(x => x.UserFee).HasPrecision(18, 2);
        builder.Property(x => x.NetAmount).HasPrecision(18, 2);
        builder.Property(x => x.ActualProviderFee).HasPrecision(18, 2);

        // Enums are stored by NAME so the table is readable directly.
        // Renaming an enum member is a data migration.
        builder.Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.Method)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.DestinationMasked)
            .HasMaxLength(100)
            .IsRequired();

        // Encrypted blob; wiped when the withdrawal reaches a final state.
        builder.Property(x => x.DestinationProtected)
            .HasMaxLength(2000);

        builder.Property(x => x.ProviderName).HasMaxLength(64);
        builder.Property(x => x.ProviderReference).HasMaxLength(100);
        builder.Property(x => x.FailureReason).HasMaxLength(500);
        builder.Property(x => x.LastError).HasMaxLength(500);
        builder.Property(x => x.ReviewNote).HasMaxLength(500);

        // Financial records are never removed by deleting a user or wallet.
        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Wallet)
            .WithMany()
            .HasForeignKey(x => x.WalletId)
            .OnDelete(DeleteBehavior.Restrict);

        // The reference is the idempotency key sent to the provider.
        builder.HasIndex(x => x.Reference)
            .IsUnique();

        builder.HasIndex(x => new { x.UserId, x.CreatedAt });

        builder.HasIndex(x => new { x.Status, x.CreatedAt });

        builder.HasIndex(x => x.ProviderReference);
    }
}
