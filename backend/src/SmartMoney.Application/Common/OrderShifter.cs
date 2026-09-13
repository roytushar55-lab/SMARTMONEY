namespace SmartMoney.Application.Common;

/// <summary>
/// Keeps sibling DisplayOrder/Priority values collision-free when an admin
/// inserts or moves an item to a position another item already occupies.
/// Callers pass the already-fetched tracked siblings; EF's change tracker
/// picks up the in-place mutations on the next SaveChangesAsync.
/// </summary>
public static class OrderShifter
{
    public static void ShiftForInsert<T>(
        IReadOnlyList<T> siblings,
        int insertOrder,
        Func<T, int> getOrder,
        Action<T, int> setOrder)
    {
        foreach (var sibling in siblings)
        {
            int current = getOrder(sibling);

            if (current >= insertOrder)
            {
                setOrder(sibling, current + 1);
            }
        }
    }

    public static void ShiftForMove<T>(
        IReadOnlyList<T> siblings,
        int oldOrder,
        int newOrder,
        Func<T, int> getOrder,
        Action<T, int> setOrder)
    {
        if (newOrder == oldOrder)
        {
            return;
        }

        foreach (var sibling in siblings)
        {
            int current = getOrder(sibling);

            if (newOrder > oldOrder && current > oldOrder && current <= newOrder)
            {
                setOrder(sibling, current - 1);
            }
            else if (newOrder < oldOrder && current >= newOrder && current < oldOrder)
            {
                setOrder(sibling, current + 1);
            }
        }
    }
}
