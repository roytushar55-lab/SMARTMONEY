using SmartMoney.Application.Features.Cashbacks.RejectCashback;
using SmartMoney.Application.Features.Cashbacks.ReverseCashback;

namespace SmartMoney.Application.Tests.Cashbacks;

/// <summary>Rejecting or reversing needs a reason; it is part of the command itself.</summary>
public sealed class DecisionReasonTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\t\n")]
    public void RejectWithoutAReasonCannotBeBuilt(string? reason)
    {
        var error = Assert.Throws<ArgumentException>(() =>
            new RejectCashbackCommand(Guid.NewGuid(), Guid.NewGuid(), reason));

        Assert.Contains("reason", error.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\t\n")]
    public void ReverseWithoutAReasonCannotBeBuilt(string? reason)
    {
        var error = Assert.Throws<ArgumentException>(() =>
            new ReverseCashbackCommand(Guid.NewGuid(), Guid.NewGuid(), reason));

        Assert.Contains("reason", error.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void TheReasonIsTrimmed()
    {
        Assert.Equal(
            "Order was returned",
            new RejectCashbackCommand(Guid.NewGuid(), Guid.NewGuid(), "  Order was returned \n").Reason);
        Assert.Equal(
            "Network clawed it back",
            new ReverseCashbackCommand(Guid.NewGuid(), Guid.NewGuid(), " Network clawed it back ").Reason);
    }
}
