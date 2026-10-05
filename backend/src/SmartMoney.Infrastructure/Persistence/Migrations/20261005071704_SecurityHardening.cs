using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartMoney.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SecurityHardening : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The Wallets/Cashbacks "xmin" concurrency token maps to Postgres' built-in
            // system column, which exists on every table already and cannot be
            // added; EF's scaffolded AddColumn/DropColumn for it were removed.

            migrationBuilder.AddColumn<int>(
                name: "FailedAttempts",
                table: "PasswordResetOtps",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "FailedAttempts",
                table: "EmailVerificationOtps",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Wallets_BalancesNonNegative",
                table: "Wallets",
                sql: "\"AvailableBalance\" >= 0 AND \"PendingBalance\" >= 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Wallets_BalancesNonNegative",
                table: "Wallets");

            migrationBuilder.DropColumn(
                name: "FailedAttempts",
                table: "PasswordResetOtps");

            migrationBuilder.DropColumn(
                name: "FailedAttempts",
                table: "EmailVerificationOtps");

        }
    }
}
