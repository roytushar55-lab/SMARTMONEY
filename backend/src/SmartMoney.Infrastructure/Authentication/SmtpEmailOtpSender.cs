using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SmartMoney.Application.Abstractions.Authentication;

namespace SmartMoney.Infrastructure.Authentication;

/// <summary>
/// Sends OTP emails over SMTP. The code is never logged. Delivery failures
/// are logged and swallowed on purpose: forgot-password must answer the same
/// way whether or not the account exists, and an exception here would make
/// "send failed" visible only for real accounts. A user whose email did not
/// arrive can simply request another code.
/// </summary>
public sealed class SmtpEmailOtpSender : IEmailOtpSender
{
    private readonly EmailOptions _options;
    private readonly ILogger<SmtpEmailOtpSender> _logger;

    public SmtpEmailOtpSender(
        IOptions<EmailOptions> options,
        ILogger<SmtpEmailOtpSender> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public Task SendAsync(
        string email,
        string otp,
        CancellationToken cancellationToken = default)
    {
        return SendMailAsync(
            email,
            "Verify your SmartMoney account",
            $"Your SmartMoney verification code is {otp}.\n\n" +
            "It expires in 2 minutes. If you didn't create a SmartMoney account, " +
            "you can ignore this email.",
            cancellationToken);
    }

    public Task SendPasswordResetOtpAsync(
        string email,
        string otp,
        CancellationToken cancellationToken = default)
    {
        return SendMailAsync(
            email,
            "Your SmartMoney password reset code",
            $"Your SmartMoney password reset code is {otp}.\n\n" +
            "It expires in 2 minutes. If you didn't ask to reset your password, " +
            "you can ignore this email; your password has not changed.",
            cancellationToken);
    }

    private async Task SendMailAsync(
        string to,
        string subject,
        string body,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(to);

        try
        {
            using var message = new MailMessage
            {
                From = new MailAddress(_options.FromAddress, _options.FromName),
                Subject = subject,
                Body = body,
                IsBodyHtml = false
            };
            message.To.Add(to);

            using var client = new SmtpClient(_options.Host, _options.Port)
            {
                EnableSsl = _options.EnableSsl,
                Timeout = 15_000
            };

            if (!string.IsNullOrWhiteSpace(_options.Username))
            {
                client.Credentials = new NetworkCredential(
                    _options.Username,
                    _options.Password);
            }

            await client.SendMailAsync(message, cancellationToken);
        }
        catch (Exception exception)
        {
            // Deliberately no recipient or code in the log line.
            _logger.LogError(exception, "Failed to send an OTP email.");
        }
    }
}
