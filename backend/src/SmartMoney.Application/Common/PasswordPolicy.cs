namespace SmartMoney.Application.Common;

/// <summary>
/// The one password rule set, used wherever a user chooses a password
/// (register, reset, change). Keeping it in one place stops a weaker path
/// from slipping in next to the strict one.
/// </summary>
public static class PasswordPolicy
{
    public const int MinLength = 8;

    /// <summary>
    /// PBKDF2 is deliberately slow, so an unbounded password would let one
    /// request burn arbitrary CPU.
    /// </summary>
    public const int MaxLength = 128;

    public static IReadOnlyCollection<string> Validate(string? password)
    {
        var errors = new List<string>();
        Validate(password, errors);
        return errors;
    }

    public static void Validate(string? password, ICollection<string> errors)
    {
        if (string.IsNullOrWhiteSpace(password))
        {
            errors.Add("Password is required.");
            return;
        }

        if (password.Length < MinLength)
        {
            errors.Add($"Password must contain at least {MinLength} characters.");
        }

        if (password.Length > MaxLength)
        {
            errors.Add($"Password must not exceed {MaxLength} characters.");
        }

        if (!password.Any(char.IsUpper))
        {
            errors.Add("Password must contain at least one uppercase letter.");
        }

        if (!password.Any(char.IsLower))
        {
            errors.Add("Password must contain at least one lowercase letter.");
        }

        if (!password.Any(char.IsDigit))
        {
            errors.Add("Password must contain at least one number.");
        }

        if (!password.Any(character => !char.IsLetterOrDigit(character)))
        {
            errors.Add("Password must contain at least one special character.");
        }
    }
}
