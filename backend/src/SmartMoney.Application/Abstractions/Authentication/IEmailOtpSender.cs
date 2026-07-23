namespace SmartMoney.Application.Abstractions.Authentication;

public interface IEmailOtpSender
{
    Task SendAsync(
        string email,
        string otp,
        CancellationToken cancellationToken = default);
}