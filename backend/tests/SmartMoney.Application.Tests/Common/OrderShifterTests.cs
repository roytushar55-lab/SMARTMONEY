using SmartMoney.Application.Common;

namespace SmartMoney.Application.Tests.Common;

public sealed class OrderShifterTests
{
    private sealed class OrderedItem
    {
        public int Order { get; set; }
    }

    [Fact]
    public void ShiftForInsert_PushesSiblingsAtOrAfterInsertOrderDown()
    {
        var siblings = new List<OrderedItem>
        {
            new() { Order = 2 },
            new() { Order = 3 },
            new() { Order = 5 }
        };

        OrderShifter.ShiftForInsert(siblings, 2, i => i.Order, (i, v) => i.Order = v);

        Assert.Equal(3, siblings[0].Order);
        Assert.Equal(4, siblings[1].Order);
        Assert.Equal(6, siblings[2].Order);
    }

    [Fact]
    public void ShiftForInsert_LeavesSiblingsBeforeInsertOrderUntouched()
    {
        var siblings = new List<OrderedItem> { new() { Order = 0 }, new() { Order = 1 } };

        OrderShifter.ShiftForInsert(siblings, 5, i => i.Order, (i, v) => i.Order = v);

        Assert.Equal(0, siblings[0].Order);
        Assert.Equal(1, siblings[1].Order);
    }

    [Fact]
    public void ShiftForMove_MovingForward_ClosesGapBetweenOldAndNewOrder()
    {
        var siblings = new List<OrderedItem>
        {
            new() { Order = 2 },
            new() { Order = 3 },
            new() { Order = 4 },
            new() { Order = 9 }
        };

        OrderShifter.ShiftForMove(siblings, oldOrder: 1, newOrder: 4, i => i.Order, (i, v) => i.Order = v);

        Assert.Equal(1, siblings[0].Order);
        Assert.Equal(2, siblings[1].Order);
        Assert.Equal(3, siblings[2].Order);
        Assert.Equal(9, siblings[3].Order);
    }

    [Fact]
    public void ShiftForMove_MovingBackward_OpensGapBetweenNewAndOldOrder()
    {
        var siblings = new List<OrderedItem>
        {
            new() { Order = 1 },
            new() { Order = 2 },
            new() { Order = 3 },
            new() { Order = 9 }
        };

        OrderShifter.ShiftForMove(siblings, oldOrder: 4, newOrder: 1, i => i.Order, (i, v) => i.Order = v);

        Assert.Equal(2, siblings[0].Order);
        Assert.Equal(3, siblings[1].Order);
        Assert.Equal(4, siblings[2].Order);
        Assert.Equal(9, siblings[3].Order);
    }

    [Fact]
    public void ShiftForMove_SameOrder_IsNoOp()
    {
        var siblings = new List<OrderedItem> { new() { Order = 3 } };

        OrderShifter.ShiftForMove(siblings, oldOrder: 2, newOrder: 2, i => i.Order, (i, v) => i.Order = v);

        Assert.Equal(3, siblings[0].Order);
    }
}
