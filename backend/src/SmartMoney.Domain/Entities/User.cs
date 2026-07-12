using SmartMoney.Domain.Common;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Domain.Entities;

public class User : BaseEntity
{
    public string FullName { get; private set; } = string.Empty;

    public string Email { get; private set; } = string.Empty;

    public string MobileNumber { get; private set; } = string.Empty;

    public string PasswordHash { get; private set; } = string.Empty;

    public UserStatus Status { get; private set; } = UserStatus.Pending;

    public Guid RoleId { get; private set; }

    public Role? Role { get; private set; }

    public bool IsEmailVerified { get; private set; }

    public bool IsMobileVerified { get; private set; }

    public bool IsActive { get; private set; } = true;

    private User()
    {
    }

    public User(
    string fullName,
    string email,
    string mobileNumber,
    string passwordHash,
    Guid roleId)
    {
        FullName = fullName;
        Email = email;
        MobileNumber = mobileNumber;
        PasswordHash = passwordHash;
        RoleId = roleId;
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

    public void ActivateAccount()
    {
        Status = UserStatus.Active;
        MarkAsUpdated();
    }

    public void SuspendAccount()
    {
        Status = UserStatus.Suspended;
        MarkAsUpdated();
    }

    public void BlockAccount()
    {
        Status = UserStatus.Blocked;
        MarkAsUpdated();
    }

    public void DeleteAccount()
    {
        Status = UserStatus.Deleted;
        MarkAsUpdated();
    }

    public void ChangeRole(Guid roleId)
    {
        RoleId = roleId;
        MarkAsUpdated();
    }
}