using SmartMoney.Application.Common;
using SmartMoney.Domain.Common;
using SmartMoney.Domain.Entities;
using SmartMoney.Infrastructure.Authentication;

namespace SmartMoney.Application.Tests.Identity;

public sealed class SecurityPolicyTests
{
    [Theory]
    [InlineData("Abcdef1!", true)]
    [InlineData("Abcdef1_", true)] // any non-alphanumeric counts as special
    [InlineData("abcdef1!", false)] // no uppercase
    [InlineData("ABCDEF1!", false)] // no lowercase
    [InlineData("Abcdefg!", false)] // no digit
    [InlineData("Abcdefg1", false)] // no special
    [InlineData("Ab1!", false)] // too short
    [InlineData("", false)]
    public void PasswordPolicy_EnforcesComplexity(string password, bool valid)
    {
        Assert.Equal(valid, PasswordPolicy.Validate(password).Count == 0);
    }

    [Fact]
    public void PasswordPolicy_RejectsOversizedPasswords()
    {
        string huge = "Aa1!" + new string('x', PasswordPolicy.MaxLength);

        Assert.NotEmpty(PasswordPolicy.Validate(huge));
    }

    [Fact]
    public void OtpPolicy_AllowsFirstCode()
    {
        Assert.True(OtpPolicy.CanIssue(new List<DateTime>(), DateTime.UtcNow));
    }

    [Fact]
    public void OtpPolicy_BlocksCodeWithinMinimumInterval()
    {
        var now = DateTime.UtcNow;

        Assert.False(OtpPolicy.CanIssue(new List<DateTime> { now.AddSeconds(-5) }, now));
        Assert.True(OtpPolicy.CanIssue(new List<DateTime> { now.AddSeconds(-90) }, now));
    }

    [Fact]
    public void OtpPolicy_BlocksAfterHourlyCap()
    {
        var now = DateTime.UtcNow;
        var five = Enumerable.Range(1, OtpPolicy.MaxIssuedPerHour)
            .Select(i => now.AddMinutes(-5 * i))
            .ToList();

        Assert.False(OtpPolicy.CanIssue(five, now));
    }

    [Fact]
    public void ConsentPolicy_OnlyKnownVersionsAreAccepted()
    {
        Assert.True(ConsentPolicy.IsAccepted(ConsentPolicy.CurrentVersion));
        Assert.False(ConsentPolicy.IsAccepted("1999-01-01"));
        Assert.False(ConsentPolicy.IsAccepted(null));
        Assert.False(ConsentPolicy.IsAccepted(""));
    }

    [Fact]
    public void RefreshToken_StoresOnlyAHash()
    {
        var token = new RefreshToken(Guid.NewGuid(), "raw-token-value", DateTime.UtcNow.AddDays(7));

        Assert.NotEqual("raw-token-value", token.Token);
        Assert.Equal(RefreshToken.HashToken("raw-token-value"), token.Token);
        Assert.NotEqual(RefreshToken.HashToken("other"), token.Token);
    }

    [Fact]
    public void PasswordHasher_RoundTrips_AndFlagsOldHashesForUpgrade()
    {
        var hasher = new PasswordHasher();

        string current = hasher.Hash("Passw0rd!");

        Assert.True(hasher.Verify("Passw0rd!", current));
        Assert.False(hasher.Verify("wrong", current));
        Assert.False(hasher.NeedsRehash(current));

        // A hash made with the previous 100k iterations still verifies but
        // is due for an upgrade.
        string[] parts = current.Split('.');
        string old = $"100000.{parts[1]}.{System.Convert.ToBase64String(
            System.Security.Cryptography.Rfc2898DeriveBytes.Pbkdf2(
                "Passw0rd!",
                System.Convert.FromBase64String(parts[1]),
                100_000,
                System.Security.Cryptography.HashAlgorithmName.SHA256,
                32))}";

        Assert.True(hasher.Verify("Passw0rd!", old));
        Assert.True(hasher.NeedsRehash(old));
    }
}
