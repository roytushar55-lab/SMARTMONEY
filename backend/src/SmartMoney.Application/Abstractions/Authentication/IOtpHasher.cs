namespace SmartMoney.Application.Abstractions.Authentication;

public interface IOtpHasher
{
    string Hash(string otp);

    bool Verify(
        string otp,
        string otpHash);
}