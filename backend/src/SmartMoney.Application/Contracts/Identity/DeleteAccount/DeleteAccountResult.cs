namespace SmartMoney.Application.Contracts.Identity.DeleteAccount;

/// <summary>
/// <paramref name="PreviousProfileImageUrl"/> is handed back so the API layer
/// can delete the stored photo (storage is not reachable from Application).
/// <paramref name="ForfeitedPendingCashback"/> is the total pending cashback
/// written off with the account.
/// </summary>
public sealed record DeleteAccountResult(
    string? PreviousProfileImageUrl,
    decimal ForfeitedPendingCashback);
