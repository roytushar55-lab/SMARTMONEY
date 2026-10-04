using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartMoney.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSignupConsentToUsers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ConsentAcceptedAt",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConsentIpAddress",
                table: "Users",
                type: "character varying(45)",
                maxLength: 45,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConsentVersion",
                table: "Users",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ConsentAcceptedAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ConsentIpAddress",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ConsentVersion",
                table: "Users");
        }
    }
}
