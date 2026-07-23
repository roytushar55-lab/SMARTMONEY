using System.Security.Cryptography;
using SmartMoney.Application.Abstractions.Authentication;

namespace SmartMoney.Infrastructure.Authentication;

public sealed class SecureOtpHasher : IOtpHasher
{
    private const int SaltSize = 16;
    private const int HashSize = 32;
    private const int Iterations = 100_000;

    public string Hash(string otp)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(otp);

        byte[] salt =
            RandomNumberGenerator.GetBytes(SaltSize);

        byte[] hash =
            Rfc2898DeriveBytes.Pbkdf2(
                otp,
                salt,
                Iterations,
                HashAlgorithmName.SHA256,
                HashSize);

        return string.Join(
            ".",
            Iterations,
            Convert.ToBase64String(salt),
            Convert.ToBase64String(hash));
    }

    public bool Verify(
        string otp,
        string otpHash)
    {
        if (string.IsNullOrWhiteSpace(otp) ||
            string.IsNullOrWhiteSpace(otpHash))
        {
            return false;
        }

        string[] parts = otpHash.Split('.');

        if (parts.Length != 3 ||
            !int.TryParse(parts[0], out int iterations))
        {
            return false;
        }

        try
        {
            byte[] salt =
                Convert.FromBase64String(parts[1]);

            byte[] expectedHash =
                Convert.FromBase64String(parts[2]);

            byte[] actualHash =
                Rfc2898DeriveBytes.Pbkdf2(
                    otp,
                    salt,
                    iterations,
                    HashAlgorithmName.SHA256,
                    expectedHash.Length);

            return CryptographicOperations.FixedTimeEquals(
                actualHash,
                expectedHash);
        }
        catch (FormatException)
        {
            return false;
        }
    }
}