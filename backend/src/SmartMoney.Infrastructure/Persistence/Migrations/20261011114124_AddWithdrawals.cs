using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartMoney.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddWithdrawals : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The Withdrawals "xmin" concurrency token maps to Postgres' built-in
            // system column, which exists on every table already and cannot be
            // created; EF's scaffolded column for it was removed (as in
            // SecurityHardening).

            migrationBuilder.DropCheckConstraint(
                name: "CK_Wallets_BalancesNonNegative",
                table: "Wallets");

            migrationBuilder.AddColumn<decimal>(
                name: "HeldBalanceAfter",
                table: "WalletTransactions",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<Guid>(
                name: "WithdrawalId",
                table: "WalletTransactions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "HeldBalance",
                table: "Wallets",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateTable(
                name: "Withdrawals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    WalletId = table.Column<Guid>(type: "uuid", nullable: false),
                    Reference = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    FeeTotal = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    UserFee = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    NetAmount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    Method = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    DestinationMasked = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    DestinationProtected = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ProviderName = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ProviderReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ActualProviderFee = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: true),
                    FailureReason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    LastError = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    SubmissionAttempts = table.Column<int>(type: "integer", nullable: false),
                    ReviewedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ReviewNote = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    NeedsAttention = table.Column<bool>(type: "boolean", nullable: false),
                    ApprovedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    SubmittedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    SettledAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Withdrawals", x => x.Id);
                    table.CheckConstraint("CK_Withdrawals_AmountsValid", "\"Amount\" > 0 AND \"NetAmount\" > 0 AND \"FeeTotal\" >= 0 AND \"UserFee\" >= 0 AND \"UserFee\" <= \"FeeTotal\"");
                    table.ForeignKey(
                        name: "FK_Withdrawals_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Withdrawals_Wallets_WalletId",
                        column: x => x.WalletId,
                        principalTable: "Wallets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WalletTransactions_WithdrawalId",
                table: "WalletTransactions",
                column: "WithdrawalId");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Wallets_BalancesNonNegative",
                table: "Wallets",
                sql: "\"AvailableBalance\" >= 0 AND \"PendingBalance\" >= 0 AND \"HeldBalance\" >= 0");

            migrationBuilder.CreateIndex(
                name: "IX_Withdrawals_ProviderReference",
                table: "Withdrawals",
                column: "ProviderReference");

            migrationBuilder.CreateIndex(
                name: "IX_Withdrawals_Reference",
                table: "Withdrawals",
                column: "Reference",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Withdrawals_Status_CreatedAt",
                table: "Withdrawals",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Withdrawals_UserId_CreatedAt",
                table: "Withdrawals",
                columns: new[] { "UserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Withdrawals_WalletId",
                table: "Withdrawals",
                column: "WalletId");

            migrationBuilder.AddForeignKey(
                name: "FK_WalletTransactions_Withdrawals_WithdrawalId",
                table: "WalletTransactions",
                column: "WithdrawalId",
                principalTable: "Withdrawals",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_WalletTransactions_Withdrawals_WithdrawalId",
                table: "WalletTransactions");

            migrationBuilder.DropTable(
                name: "Withdrawals");

            migrationBuilder.DropIndex(
                name: "IX_WalletTransactions_WithdrawalId",
                table: "WalletTransactions");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Wallets_BalancesNonNegative",
                table: "Wallets");

            migrationBuilder.DropColumn(
                name: "HeldBalanceAfter",
                table: "WalletTransactions");

            migrationBuilder.DropColumn(
                name: "WithdrawalId",
                table: "WalletTransactions");

            migrationBuilder.DropColumn(
                name: "HeldBalance",
                table: "Wallets");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Wallets_BalancesNonNegative",
                table: "Wallets",
                sql: "\"AvailableBalance\" >= 0 AND \"PendingBalance\" >= 0");
        }
    }
}
