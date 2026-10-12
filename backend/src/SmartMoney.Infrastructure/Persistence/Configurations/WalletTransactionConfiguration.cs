using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class WalletTransactionConfiguration
    : IEntityTypeConfiguration<WalletTransaction>
{
    public void Configure(EntityTypeBuilder<WalletTransaction> builder)
    {
        builder.ToTable("WalletTransactions");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Amount)
            .HasPrecision(18, 2);

        builder.Property(x => x.AvailableBalanceAfter)
            .HasPrecision(18, 2);

        builder.Property(x => x.PendingBalanceAfter)
            .HasPrecision(18, 2);

        builder.Property(x => x.HeldBalanceAfter)
            .HasPrecision(18, 2);

        // Stored as the enum NAME ("CashbackPending", ...) so the ledger is
        // readable directly and admin tooling never has to map magic numbers.
        // Renaming an enum member is a data migration.
        builder.Property(x => x.Type)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.Description)
            .HasMaxLength(256);

        builder.HasOne(x => x.Wallet)
            .WithMany()
            .HasForeignKey(x => x.WalletId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Cashback)
            .WithMany()
            .HasForeignKey(x => x.CashbackId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Withdrawal)
            .WithMany()
            .HasForeignKey(x => x.WithdrawalId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(x => new { x.WalletId, x.CreatedAt });

        builder.HasIndex(x => new { x.UserId, x.CreatedAt });

        builder.HasIndex(x => x.CashbackId);

        builder.HasIndex(x => x.WithdrawalId);
    }
}
