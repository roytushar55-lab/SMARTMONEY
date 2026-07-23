using Microsoft.Extensions.Logging;
using SmartMoney.Application.Abstractions.Authentication;

namespace SmartMoney.Infrastructure.Authentication;

public sealed class ConsoleEmailOtpSender : IEmailOtpSender
{
    private readonly ILogger<ConsoleEmailOtpSender> _logger;

    public ConsoleEmailOtpSender(
        ILogger<ConsoleEmailOtpSender> logger)
    {
        _logger = logger;
    }

    public Task SendAsync(
        string email,
        string otp,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(email);
        ArgumentException.ThrowIfNullOrWhiteSpace(otp);

        _logger.LogInformation(
            """
            
            ========================================
            SMART MONEY EMAIL VERIFICATION OTP
            Email: {Email}
            OTP: {Otp}
            ========================================
            
            """,
            email,
            otp);

        return Task.CompletedTask;
    }
}