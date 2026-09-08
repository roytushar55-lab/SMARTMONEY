using SmartMoney.Application.Common;

namespace SmartMoney.Application.Tests.Common;

public sealed class SlugGeneratorTests
{
    [Theory]
    [InlineData("Myntra Fashion", "myntra-fashion")]
    [InlineData("  Trim Me  ", "trim-me")]
    [InlineData("Multiple   Spaces", "multiple-spaces")]
    [InlineData("Special!!Chars??", "special-chars")]
    [InlineData("UPPER case", "upper-case")]
    [InlineData("Trailing-Punct!", "trailing-punct")]
    public void Generate_ProducesExpectedSlug(string input, string expected)
    {
        Assert.Equal(expected, SlugGenerator.Generate(input));
    }

    [Theory]
    [InlineData("!!!")]
    [InlineData("   ")]
    [InlineData("")]
    public void Generate_NoUsableCharacters_ReturnsEmpty(string input)
    {
        Assert.Equal(string.Empty, SlugGenerator.Generate(input));
    }
}
