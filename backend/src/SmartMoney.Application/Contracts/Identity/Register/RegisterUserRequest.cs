using System.ComponentModel.DataAnnotations;

namespace SmartMoney.Api.Features.Identity.Register;

public sealed class RegisterUserRequest
{
    [Required]
    [StringLength(100, MinimumLength = 2)]
    public string FullName { get; init; } = string.Empty;

    [Required]
    [EmailAddress]
    [StringLength(254)]
    public string Email { get; init; } = string.Empty;

    [Required]
    [StringLength(15, MinimumLength = 10)]
    public string PhoneNumber { get; init; } = string.Empty;

    [Required]
    [StringLength(128, MinimumLength = 8)]
    public string Password { get; init; } = string.Empty;

    [StringLength(50)]
    public string? ReferralCode { get; init; }
}