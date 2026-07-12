using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class CashbackConfiguration : IEntityTypeConfiguration<Cashback>
{
    public void Configure(EntityTypeBuilder<Cashback> builder)
    {
        builder.ToTable("Cashbacks");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.CommissionAmount)
            .HasPrecision(18, 2);

        builder.Property(x => x.CashbackAmount)
            .HasPrecision(18, 2);

        builder.Property(x => x.Status)
            .HasConversion<int>()
            .IsRequired();

        builder.Property(x => x.PurchaseDate)
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
    }
}