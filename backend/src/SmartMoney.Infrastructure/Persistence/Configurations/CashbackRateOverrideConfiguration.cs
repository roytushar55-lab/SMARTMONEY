using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class CashbackRateOverrideConfiguration : IEntityTypeConfiguration<CashbackRateOverride>
{
    public void Configure(EntityTypeBuilder<CashbackRateOverride> builder)
    {
        builder.ToTable("CashbackRateOverrides");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.UserSharePercent)
            .HasPrecision(5, 2)
            .IsRequired();

        builder.Property(x => x.ConfirmationWindowDays)
            .IsRequired();

        builder.Property(x => x.IsActive)
            .IsRequired();

        builder.HasOne(x => x.AffiliateNetwork)
            .WithMany()
            .HasForeignKey(x => x.AffiliateNetworkId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Store)
            .WithMany()
            .HasForeignKey(x => x.StoreId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Category)
            .WithMany()
            .HasForeignKey(x => x.CategoryId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.AffiliateNetworkId, x.StoreId, x.CategoryId })
            .IsUnique();
    }
}
