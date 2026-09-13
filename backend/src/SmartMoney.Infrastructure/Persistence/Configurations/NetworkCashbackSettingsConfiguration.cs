using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class NetworkCashbackSettingsConfiguration : IEntityTypeConfiguration<NetworkCashbackSettings>
{
    public void Configure(EntityTypeBuilder<NetworkCashbackSettings> builder)
    {
        builder.ToTable("NetworkCashbackSettings");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.UserSharePercent)
            .HasPrecision(5, 2)
            .IsRequired();

        builder.Property(x => x.ConfirmationWindowDays)
            .IsRequired();

        builder.HasOne(x => x.AffiliateNetwork)
            .WithMany()
            .HasForeignKey(x => x.AffiliateNetworkId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => x.AffiliateNetworkId)
            .IsUnique();
    }
}
