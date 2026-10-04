using SmartMoney.Application.Features.Identity.Register;

namespace SmartMoney.Application.Tests.Identity;

public sealed class RegisterUserValidatorTests
{
    private readonly RegisterUserValidator _validator = new();

    private static RegisterUserCommand CreateCommand(
        bool ageConfirmed = true,
        bool termsAccepted = true,
        string? consentVersion = "2026-10-02")
    {
        return new RegisterUserCommand(
            "Test User",
            "test@example.com",
            "9876543210",
            "Passw0rd!",
            null,
            ageConfirmed,
            termsAccepted,
            consentVersion,
            "203.0.113.5");
    }

    [Fact]
    public void Validate_WithConsent_ReturnsNoErrors()
    {
        Assert.Empty(_validator.Validate(CreateCommand()));
    }

    [Fact]
    public void Validate_WithoutAgeConfirmation_ReturnsError()
    {
        var errors = _validator.Validate(CreateCommand(ageConfirmed: false));

        Assert.Contains(errors, e => e.Contains("18 years"));
    }

    [Fact]
    public void Validate_WithoutTermsAcceptance_ReturnsError()
    {
        var errors = _validator.Validate(CreateCommand(termsAccepted: false));

        Assert.Contains(errors, e => e.Contains("Terms of Service"));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Validate_WithoutConsentVersion_ReturnsError(string? version)
    {
        var errors = _validator.Validate(CreateCommand(consentVersion: version));

        Assert.Contains(errors, e => e.Contains("Consent version"));
    }
}
