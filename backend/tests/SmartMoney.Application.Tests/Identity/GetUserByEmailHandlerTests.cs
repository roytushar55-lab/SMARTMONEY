using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Identity.GetUserByEmail;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Identity;

public sealed class GetUserByEmailHandlerTests
{
    private readonly Mock<IUserRepository> _users = new();

    private GetUserByEmailQueryHandler CreateHandler()
    {
        return new GetUserByEmailQueryHandler(_users.Object);
    }

    [Fact]
    public async Task ExistingUser_ReturnsLookupResponse()
    {
        var role = new Role(RoleType.Admin, "System administrator");
        var user = new User("Jane Doe", "jane@example.com", "9999999999", "hash", role.Id);
        typeof(User).GetProperty(nameof(User.Role))!.SetValue(user, role);
        _users.Setup(u => u.GetByEmailAsync("jane@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        var response = await CreateHandler().HandleAsync(
            new GetUserByEmailQuery("jane@example.com"), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal(user.Id, response!.UserId);
        Assert.Equal("Admin", response.Role);
        Assert.True(response.IsActive);
    }

    [Fact]
    public async Task UnknownEmail_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new GetUserByEmailQuery("nobody@example.com"), CancellationToken.None);

        Assert.Null(response);
    }

    [Fact]
    public async Task BlankEmail_ReturnsNull()
    {
        var response = await CreateHandler().HandleAsync(
            new GetUserByEmailQuery(""), CancellationToken.None);

        Assert.Null(response);
        _users.Verify(
            u => u.GetByEmailAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
