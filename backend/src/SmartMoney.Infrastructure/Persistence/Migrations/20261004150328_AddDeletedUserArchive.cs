using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartMoney.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDeletedUserArchive : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DeletedUserArchives",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    FullName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    Email = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    MobileNumber = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PurgeAfter = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeletedUserArchives", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DeletedUserArchives_PurgeAfter",
                table: "DeletedUserArchives",
                column: "PurgeAfter");

            migrationBuilder.CreateIndex(
                name: "IX_DeletedUserArchives_UserId",
                table: "DeletedUserArchives",
                column: "UserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DeletedUserArchives");
        }
    }
}
