using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Identity.UpdateUserStatus;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Identity;

public sealed class UpdateUserStatusHandlerTests
{
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private UpdateUserStatusCommandHandler CreateHandler()
    {
        return new UpdateUserStatusCommandHandler(
            _users.Object,
            _unitOfWork.Object);
    }

    private static User NewUser()
    {
        return new User(
            "Test User",
            "test@example.com",
            "9876543210",
            "hash",
            Guid.NewGuid());
    }

    [Fact]
    public async Task Handle_Activate_OnDeletedAccount_Throws_AndSavesNothing()
    {
        var user = NewUser();
        user.AnonymizeForDeletion();
        _users.Setup(u => u.GetByIdAsync(user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateHandler().HandleAsync(
                new UpdateUserStatusCommand(user.Id, true, Guid.NewGuid()),
                CancellationToken.None));

        Assert.False(user.IsActive);
        _unitOfWork.Verify(
            u => u.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task Handle_Activate_OnDeactivatedUser_Succeeds()
    {
        var user = NewUser();
        user.Deactivate();
        _users.Setup(u => u.GetByIdAsync(user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        var result = await CreateHandler().HandleAsync(
            new UpdateUserStatusCommand(user.Id, true, Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(result!.IsActive);
    }
}
