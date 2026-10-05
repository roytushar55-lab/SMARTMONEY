namespace SmartMoney.Application.Abstractions.Authentication;

public interface IPasswordHasher
{
    string Hash(string password);

    bool Verify(
        string password,
        string passwordHash);

    /// <summary>
    /// True when a stored hash was made with weaker parameters than the
    /// current ones and should be recomputed (after a successful login, when
    /// the plaintext is available).
    /// </summary>
    bool NeedsRehash(string passwordHash);
}