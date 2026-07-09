using SmartMoney.Domain.Common;

namespace SmartMoney.Domain.Entities;

public class User : BaseEntity
{
    public string FullName { get; private set; } = string.Empty;

    public string Email { get; private set; } = string.Empty;

    public string MobileNumber { get; private set; } = string.Empty;

    public string PasswordHash { get; private set; } = string.Empty;

    public bool IsEmailVerified { get; private set; }

    public bool IsMobileVerified { get; private set; }

    public bool IsActive { get; private set; } = true;

    public User()
    {
    }

    public User(
        string fullName,
        string email,
        string mobileNumber,
        string passwordHash)
    {
        FullName = fullName;
        Email = email;
        MobileNumber = mobileNumber;
        PasswordHash = passwordHash;
    }

    public void VerifyEmail()
    {
        IsEmailVerified = true;
        MarkAsUpdated();
    }

    public void VerifyMobile()
    {
        IsMobileVerified = true;
        MarkAsUpdated();
    }

    public void Deactivate()
    {
        IsActive = false;
        MarkAsUpdated();
    }
}