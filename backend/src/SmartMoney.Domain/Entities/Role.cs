using SmartMoney.Domain.Common;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Domain.Entities;

public sealed class Role : BaseEntity
{
    public RoleType Name { get; private set; }

    public string Description { get; private set; } = string.Empty;

    private Role()
    {
    }

    public Role(RoleType name, string description)
    {
        Name = name;
        Description = description;
    }

    public void UpdateDescription(string description)
    {
        Description = description;

        MarkAsUpdated();
    }
}