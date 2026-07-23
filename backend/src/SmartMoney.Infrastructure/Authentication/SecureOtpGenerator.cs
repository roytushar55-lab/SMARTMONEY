using System.Security.Cryptography;
using SmartMoney.Application.Abstractions.Authentication;

namespace SmartMoney.Infrastructure.Authentication;

public sealed class SecureOtpGenerator : IOtpGenerator
{
    public string Generate(int length = 6)
    {
        if (length <= 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(length),
                "OTP length must be greater than zero.");
        }

        Span<char> digits = stackalloc char[length];

        for (int index = 0; index < length; index++)
        {
            digits[index] = (char)(
                '0' + RandomNumberGenerator.GetInt32(0, 10));
        }

        return new string(digits);
    }
}