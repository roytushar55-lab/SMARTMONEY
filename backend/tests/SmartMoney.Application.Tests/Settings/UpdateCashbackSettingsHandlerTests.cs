using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.CashbackSettings.UpdateCashbackSettings;
using SmartMoney.Domain.Entities;

namespace SmartMoney.Application.Tests.Settings;

public sealed class UpdateCashbackSettingsHandlerTests
{
    private readonly Mock<ICashbackSettingsRepository> _settings = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    private UpdateCashbackSettingsCommandHandler CreateHandler()
    {
        return new UpdateCashbackSettingsCommandHandler(
            _settings.Object, new UpdateCashbackSettingsValidator(), _unitOfWork.Object);
    }

    [Fact]
    public async Task ValidRequest_UpdatesSharePercentAndWindow()
    {
        var existing = new CashbackSettings
        {
            UserSharePercent = 60.00m,
            ConfirmationWindowDays = 60
        };
        _settings.Setup(s => s.GetTrackedAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(existing);

        var response = await CreateHandler().HandleAsync(
            new UpdateCashbackSettingsCommand(75.00m, 45), CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal(75.00m, response!.UserSharePercent);
        Assert.Equal(45, response.ConfirmationWindowDays);
        Assert.Equal(75.00m, existing.UserSharePercent);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task NoSettingsRow_ReturnsNull()
    {
        _settings.Setup(s => s.GetTrackedAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync((CashbackSettings?)null);

        var response = await CreateHandler().HandleAsync(
            new UpdateCashbackSettingsCommand(60.00m, 60), CancellationToken.None);

        Assert.Null(response);
    }

    [Theory]
    [InlineData(0, 60)]
    [InlineData(101, 60)]
    [InlineData(-5, 60)]
    [InlineData(60, 0)]
    [InlineData(60, -1)]
    public async Task OutOfRangeValues_ThrowArgumentException(decimal share, int windowDays)
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            CreateHandler().HandleAsync(
                new UpdateCashbackSettingsCommand(share, windowDays), CancellationToken.None));

        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
