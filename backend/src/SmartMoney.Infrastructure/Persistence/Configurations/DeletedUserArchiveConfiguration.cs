using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Infrastructure.Persistence.Configurations;

public sealed class DeletedUserArchiveConfiguration
    : IEntityTypeConfiguration<DeletedUserArchive>
{
    public void Configure(EntityTypeBuilder<DeletedUserArchive> builder)
    {
        builder.ToTable("DeletedUserArchives");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.FullName)
            .HasMaxLength(150)
            .IsRequired();

        builder.Property(x => x.Email)
            .HasMaxLength(150)
            .IsRequired();

        builder.Property(x => x.MobileNumber)
            .HasMaxLength(20)
            .IsRequired();

        builder.HasIndex(x => x.UserId)
            .IsUnique();

        // Purge job/startup sweep filters on this.
        builder.HasIndex(x => x.PurgeAfter);
    }
}
