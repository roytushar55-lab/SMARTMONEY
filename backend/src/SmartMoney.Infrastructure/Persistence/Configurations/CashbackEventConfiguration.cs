using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class CashbackEventConfiguration : IEntityTypeConfiguration<CashbackEvent>
{
    public void Configure(EntityTypeBuilder<CashbackEvent> builder)
    {
        builder.ToTable("CashbackEvents");

        builder.HasKey(x => x.Id);

        // Stored as names so the trail is readable straight from the database.
        builder.Property(x => x.Type)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.FromStatus)
            .HasConversion<string>()
            .HasMaxLength(32);

        builder.Property(x => x.ToStatus)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.Amount)
            .HasPrecision(18, 2);

        builder.Property(x => x.NetworkStatus)
            .HasMaxLength(64);

        builder.Property(x => x.Reason)
            .HasMaxLength(CashbackEvent.MaxReasonLength);

        // The trail goes with the cashback if it is ever deleted; the acting
        // admin is only a reference, so removing an account never erases history.
        builder.HasOne(x => x.Cashback)
            .WithMany()
            .HasForeignKey(x => x.CashbackId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Actor)
            .WithMany()
            .HasForeignKey(x => x.ActorUserId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(x => new { x.CashbackId, x.CreatedAt });
    }
}
