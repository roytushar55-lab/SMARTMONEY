using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks.ListCashbacks;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Cashbacks;

public sealed class ListCashbacksHandlerTests
{
    private readonly Mock<ICashbackRepository> _cashbacks = new();

    private ListCashbacksQueryHandler CreateHandler()
    {
        return new ListCashbacksQueryHandler(_cashbacks.Object);
    }

    // EF populates the private-setter navigations at runtime; tests do the
    // same via reflection since the aggregate exposes no public way in.
    private static void SetNavigation(object entity, string property, object value)
    {
        entity.GetType().GetProperty(property)!.SetValue(entity, value);
    }

    private static Cashback NewCashbackGraph(string? storeName)
    {
        var user = new User(
            "Test User", "user@example.com", "9999999999", "hash", Guid.NewGuid());

        var conversion = new AffiliateConversion
        {
            NetworkTransactionId = "TXN-1",
            NetworkStatus = "validated",
            OrderAmount = 2499.00m,
            CommissionAmount = 250.00m,
            Currency = "INR",
            AffiliateClick = storeName is null
                ? null
                : new AffiliateClick { Store = new Store { Name = storeName } },
        };

        var cashback = new Cashback(
            user.Id, Guid.NewGuid(), conversion.Id, 150.00m,
            DateTime.UtcNow.AddDays(60));
        cashback.FlagForReview();

        SetNavigation(cashback, nameof(Cashback.User), user);
        SetNavigation(cashback, nameof(Cashback.AffiliateConversion), conversion);

        return cashback;
    }

    [Fact]
    public async Task MapsEntityGraphIncludingNetworkStatusAndStore()
    {
        var cashback = NewCashbackGraph("Myntra");
        _cashbacks.Setup(c => c.ListAsync(
                It.Is<CashbackListFilter>(f => f.Status == CashbackStatus.AwaitingAdminReview),
                1, 20, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { cashback });
        _cashbacks.Setup(c => c.CountAsync(
                It.Is<CashbackListFilter>(f => f.Status == CashbackStatus.AwaitingAdminReview),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        var response = await CreateHandler().HandleAsync(
            new ListCashbacksQuery(
                new CashbackListFilter { Status = CashbackStatus.AwaitingAdminReview }, 1, 20),
            CancellationToken.None);

        var item = Assert.Single(response.Items);
        Assert.Equal(cashback.Id, item.Id);
        Assert.Equal("user@example.com", item.UserEmail);
        Assert.Equal("Test User", item.UserFullName);
        Assert.Equal("Myntra", item.StoreName);
        Assert.Equal("AwaitingAdminReview", item.Status);
        Assert.Equal("validated", item.NetworkStatus);
        Assert.Equal(250.00m, item.CommissionAmount);
        Assert.Equal(150.00m, item.CashbackAmount);
        Assert.Equal(1, response.TotalCount);
    }

    [Fact]
    public async Task RowsCarryTheirQueueAndOverdueFlag()
    {
        // Validated and not yet decided: ready to approve. Expected date is 60
        // days out, so it is only overdue when "now" is later than that.
        var cashback = NewCashbackGraph("Myntra");
        _cashbacks.Setup(c => c.ListAsync(
                It.IsAny<CashbackListFilter>(), 1, 20, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { cashback });
        _cashbacks.Setup(c => c.CountAsync(
                It.IsAny<CashbackListFilter>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        var onTime = await CreateHandler().HandleAsync(
            new ListCashbacksQuery(new CashbackListFilter(), 1, 20), CancellationToken.None);
        var late = await CreateHandler().HandleAsync(
            new ListCashbacksQuery(
                new CashbackListFilter { NowUtc = DateTime.UtcNow.AddDays(90) }, 1, 20),
            CancellationToken.None);

        Assert.Equal("ReadyToApprove", Assert.Single(onTime.Items).Queue);
        Assert.False(onTime.Items[0].IsOverdue);
        Assert.True(Assert.Single(late.Items).IsOverdue);
    }

    [Fact]
    public async Task UnattributedClickChain_MapsNullStoreWithoutThrowing()
    {
        var cashback = NewCashbackGraph(storeName: null);
        _cashbacks.Setup(c => c.ListAsync(
                It.IsAny<CashbackListFilter>(), 1, 20, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { cashback });
        _cashbacks.Setup(c => c.CountAsync(
                It.IsAny<CashbackListFilter>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        var response = await CreateHandler().HandleAsync(
            new ListCashbacksQuery(new CashbackListFilter(), 1, 20), CancellationToken.None);

        Assert.Null(Assert.Single(response.Items).StoreName);
    }

    [Theory]
    [InlineData(0, 0, 1, 20)]     // defaults kick in
    [InlineData(-3, 500, 1, 100)] // clamped to floor / ceiling
    [InlineData(2, 50, 2, 50)]    // sane values pass through
    public async Task PagingIsClamped(
        int requestedPage, int requestedSize, int expectedPage, int expectedSize)
    {
        _cashbacks.Setup(c => c.ListAsync(
                It.IsAny<CashbackListFilter>(), expectedPage, expectedSize,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(Array.Empty<Cashback>());
        _cashbacks.Setup(c => c.CountAsync(
                It.IsAny<CashbackListFilter>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(0);

        var response = await CreateHandler().HandleAsync(
            new ListCashbacksQuery(new CashbackListFilter(), requestedPage, requestedSize),
            CancellationToken.None);

        Assert.Equal(expectedPage, response.Page);
        Assert.Equal(expectedSize, response.PageSize);
        _cashbacks.Verify(c => c.ListAsync(
            It.IsAny<CashbackListFilter>(), expectedPage, expectedSize,
            It.IsAny<CancellationToken>()));
    }
}
