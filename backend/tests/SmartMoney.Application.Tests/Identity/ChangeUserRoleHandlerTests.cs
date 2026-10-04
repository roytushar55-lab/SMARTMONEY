using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Identity.ChangeUserRole;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Identity;

public sealed class ChangeUserRoleHandlerTests
{
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IRoleRepository> _roles = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private readonly Guid _actingUserId = Guid.NewGuid();
    private readonly Role _adminRole = new(RoleType.Admin, "System administrator");
    private readonly Role _customerRole = new(RoleType.Customer, "Default customer");

    public ChangeUserRoleHandlerTests()
    {
        _roles.Setup(r => r.GetByNameAsync(RoleType.Admin, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_adminRole);
        _roles.Setup(r => r.GetByNameAsync(RoleType.Customer, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_customerRole);
    }

    private ChangeUserRoleCommandHandler CreateHandler()
    {
        return new ChangeUserRoleCommandHandler(
            _users.Object,
            _roles.Object,
            new ChangeUserRoleValidator(),
            _unitOfWork.Object);
    }

    private User NewCustomer()
    {
        var user = new User(
            "Target User", "target@example.com", "8888888888", "hash",
            _customerRole.Id);

        _users.Setup(u => u.GetByIdAsync(user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        return user;
    }

    [Fact]
    public async Task PromotesCustomerToAdmin()
    {
        var user = NewCustomer();

        var response = await CreateHandler().HandleAsync(
            new ChangeUserRoleCommand(user.Id, "admin", _actingUserId),
            CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal("Admin", response!.Role);
        Assert.Equal(_adminRole.Id, user.RoleId);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData("SuperAdmin")] // config-seeded only, never API-assignable
    [InlineData("Support")]
    [InlineData("Finance")]
    [InlineData("garbage")]
    [InlineData("")]
    public async Task NonAssignableRole_ThrowsArgumentException(string role)
    {
        var user = NewCustomer();

        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(
                new ChangeUserRoleCommand(user.Id, role, _actingUserId),
                CancellationToken.None));

        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SelfChange_ThrowsInvalidOperation()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new ChangeUserRoleCommand(_actingUserId, "Admin", _actingUserId),
                CancellationToken.None));

        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task UnknownUser_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new ChangeUserRoleCommand(Guid.NewGuid(), "Admin", _actingUserId),
            CancellationToken.None);

        Assert.Null(response);
    }

    [Fact]
    public async Task DeletedAccount_CannotChangeRole()
    {
        var user = NewCustomer();
        user.AnonymizeForDeletion();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new ChangeUserRoleCommand(user.Id, "admin", _actingUserId),
                CancellationToken.None));

        Assert.Equal(_customerRole.Id, user.RoleId);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
