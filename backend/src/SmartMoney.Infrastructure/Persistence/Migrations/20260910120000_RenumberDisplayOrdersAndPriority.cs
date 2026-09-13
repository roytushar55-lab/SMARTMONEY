using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartMoney.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// One-time data fix: Category.DisplayOrder, Store.DisplayOrder, and
    /// Offer.Priority had no collision handling before this release, so the
    /// admin UI could silently give two rows the same order value. This
    /// renumbers each table using the exact tie-break the read paths already
    /// use, so today's visible ordering is preserved — only duplicates/gaps
    /// are removed. Going forward, CreateXCommandHandler/UpdateXCommandHandler
    /// shift siblings automatically (see OrderShifter), so duplicates should
    /// not reappear.
    /// </summary>
    /// <inheritdoc />
    public partial class RenumberDisplayOrdersAndPriority : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                WITH ranked AS (
                    SELECT "Id", ROW_NUMBER() OVER (ORDER BY "DisplayOrder", "Name") - 1 AS new_order
                    FROM "Categories"
                )
                UPDATE "Categories" c SET "DisplayOrder" = r.new_order
                FROM ranked r WHERE r."Id" = c."Id";
                """);

            migrationBuilder.Sql(
                """
                WITH ranked AS (
                    SELECT "Id", ROW_NUMBER() OVER (ORDER BY "DisplayOrder", "Name") - 1 AS new_order
                    FROM "Stores"
                )
                UPDATE "Stores" s SET "DisplayOrder" = r.new_order
                FROM ranked r WHERE r."Id" = s."Id";
                """);

            migrationBuilder.Sql(
                """
                WITH ranked AS (
                    SELECT "Id", ROW_NUMBER() OVER (ORDER BY "IsFeatured" DESC, "Priority", "Title") - 1 AS new_order
                    FROM "Offers"
                )
                UPDATE "Offers" o SET "Priority" = r.new_order
                FROM ranked r WHERE r."Id" = o."Id";
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Data-only cleanup; the original (duplicate/gapped) order values
            // are not recoverable, so there is nothing meaningful to revert.
        }
    }
}
