namespace SmartMoney.Application.Abstractions.Persistence;

/// <summary>
/// Raised when a save loses a race against another request that changed the
/// same row (for example two admins approving cashback for the same wallet at
/// once). Nothing was written; the caller should reload and retry. Mapped to
/// HTTP 409 by the API's exception handler.
/// </summary>
public sealed class ConcurrencyConflictException : Exception
{
    public ConcurrencyConflictException(Exception innerException)
        : base(
            "This record was changed by someone else. Please refresh and try again.",
            innerException)
    {
    }
}
