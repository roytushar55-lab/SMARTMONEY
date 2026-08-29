namespace SmartMoney.Application.Abstractions.Authentication;

/// <summary>
/// The claims we trust from a verified Google ID token — never the raw,
/// client-supplied email/name a caller could fabricate.
/// </summary>
public sealed record GoogleIdTokenPayload(
    string Subject,
    string Email,
    bool EmailVerified,
    string FullName);
