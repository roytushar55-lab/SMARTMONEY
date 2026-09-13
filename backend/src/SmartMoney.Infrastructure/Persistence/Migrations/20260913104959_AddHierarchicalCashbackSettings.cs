using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartMoney.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHierarchicalCashbackSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CashbackRateOverrides",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AffiliateNetworkId = table.Column<Guid>(type: "uuid", nullable: false),
                    StoreId = table.Column<Guid>(type: "uuid", nullable: false),
                    CategoryId = table.Column<Guid>(type: "uuid", nullable: true),
                    UserSharePercent = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: false),
                    ConfirmationWindowDays = table.Column<int>(type: "integer", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CashbackRateOverrides", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CashbackRateOverrides_AffiliateNetworks_AffiliateNetworkId",
                        column: x => x.AffiliateNetworkId,
                        principalTable: "AffiliateNetworks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CashbackRateOverrides_Categories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "Categories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CashbackRateOverrides_Stores_StoreId",
                        column: x => x.StoreId,
                        principalTable: "Stores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "NetworkCashbackSettings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AffiliateNetworkId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserSharePercent = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: false),
                    ConfirmationWindowDays = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NetworkCashbackSettings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NetworkCashbackSettings_AffiliateNetworks_AffiliateNetworkId",
                        column: x => x.AffiliateNetworkId,
                        principalTable: "AffiliateNetworks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CashbackRateOverrides_AffiliateNetworkId_StoreId_CategoryId",
                table: "CashbackRateOverrides",
                columns: new[] { "AffiliateNetworkId", "StoreId", "CategoryId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CashbackRateOverrides_CategoryId",
                table: "CashbackRateOverrides",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_CashbackRateOverrides_StoreId",
                table: "CashbackRateOverrides",
                column: "StoreId");

            migrationBuilder.CreateIndex(
                name: "IX_NetworkCashbackSettings_AffiliateNetworkId",
                table: "NetworkCashbackSettings",
                column: "AffiliateNetworkId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CashbackRateOverrides");

            migrationBuilder.DropTable(
                name: "NetworkCashbackSettings");
        }
    }
}
