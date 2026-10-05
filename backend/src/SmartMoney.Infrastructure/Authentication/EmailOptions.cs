namespace SmartMoney.Infrastructure.Authentication;

/// <summary>
/// SMTP settings for transactional email (OTP codes). Works with any SMTP
/// provider (Amazon SES, SendGrid, Brevo, Gmail...). Supply the password via
/// an environment variable / secret store (Email__Password), never appsettings.
/// </summary>
public sealed class EmailOptions
{
    public const string SectionName = "Email";

    public string Host { get; init; } = string.Empty;

    public int Port { get; init; } = 587;

    public string Username { get; init; } = string.Empty;

    public string Password { get; init; } = string.Empty;

    public string FromAddress { get; init; } = string.Empty;

    public string FromName { get; init; } = "SmartMoney";

    public bool EnableSsl { get; init; } = true;
}
