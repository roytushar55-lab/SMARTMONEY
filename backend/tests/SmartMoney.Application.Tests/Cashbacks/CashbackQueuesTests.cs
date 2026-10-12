using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Cashbacks;
using SmartMoney.Application.Features.Cashbacks.GetCashbackSummary;
using SmartMoney.Application.Features.Cashbacks.ListCashbacks;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Cashbacks;

/// <summary>
/// The queue rules and list filters are expression trees the database runs;
/// these tests run the very same expressions over in-memory objects.
/// </summary>
public sealed class CashbackQueuesTests
{
    public enum Stage
    {
        Pending,
        AwaitingNeverConfirmed,
        AwaitingAfterConfirmed,
        Confirmed,
        Rejected,
        Reversed,
        PaidOut
    }

    private static readonly DateTime Now = new(2026, 10, 12, 12, 0, 0, DateTimeKind.Utc);

    private static void Set(object entity, string property, object? value)
    {
        entity.GetType().GetProperty(property)!.SetValue(entity, value);
    }

    private static Cashback Make(
        Stage stage,
        string networkStatus,
        decimal amount = 150m,
        DateTime? expected = null,
        DateTime? created = null,
        string fullName = "Asha Rao",
        string email = "asha@example.com",
        string? store = "Myntra",
        decimal? order = 2499m,
        decimal? commission = 250m)
    {
        var user = new User(fullName, email, "9999999999", "hash", Guid.NewGuid());

        var conversion = new AffiliateConversion
        {
            NetworkTransactionId = "TXN-" + Guid.NewGuid(),
            NetworkStatus = networkStatus,
            OrderAmount = order,
            CommissionAmount = commission,
            Currency = "INR",
            AffiliateClick = store is null
                ? null
                : new AffiliateClick { Store = new Store { Name = store } }
        };

        var cashback = new Cashback(
            user.Id, Guid.NewGuid(), conversion.Id, amount, expected ?? Now.AddDays(30));

        switch (stage)
        {
            case Stage.AwaitingNeverConfirmed:
                cashback.FlagForReview();
                break;
            case Stage.AwaitingAfterConfirmed:
                cashback.Confirm();
                cashback.FlagForReview();
                break;
            case Stage.Confirmed:
                cashback.Confirm();
                break;
            case Stage.Rejected:
                cashback.Reject();
                break;
            case Stage.Reversed:
                cashback.Confirm();
                cashback.FlagForReview();
                cashback.Reverse();
                break;
            case Stage.PaidOut:
                cashback.Confirm();
                cashback.MarkAsPaidOut();
                break;
        }

        Set(cashback, nameof(Cashback.User), user);
        Set(cashback, nameof(Cashback.AffiliateConversion), conversion);

        if (created is not null)
        {
            Set(cashback, nameof(Cashback.CreatedAt), created.Value);
        }

        return cashback;
    }

    private static List<Cashback> Apply(IEnumerable<Cashback> cashbacks, CashbackListFilter filter)
    {
        IQueryable<Cashback> query = cashbacks.AsQueryable();

        foreach (var predicate in filter.Predicates())
        {
            query = query.Where(predicate);
        }

        return query.ToList();
    }

    // ---- every cashback is in exactly one queue ---------------------------

    public static IEnumerable<object[]> EveryStageAndNetworkWord()
    {
        string[] words =
        {
            "pending", "validated", "paid", "rejected", "cancelled", "canceled",
            "reversed", "", "something-new", "  Validated ", "REJECTED"
        };

        foreach (Stage stage in Enum.GetValues<Stage>())
        {
            foreach (string word in words)
            {
                yield return new object[] { stage, word };
            }
        }
    }

    [Theory]
    [MemberData(nameof(EveryStageAndNetworkWord))]
    public void EveryCashbackIsInExactlyOneQueue_AndClassifyAgrees(Stage stage, string word)
    {
        var cashback = Make(stage, word);

        var matching = Enum.GetValues<CashbackQueue>()
            .Where(queue => CashbackQueues.Matches(queue).Compile()(cashback))
            .ToList();

        var only = Assert.Single(matching);
        Assert.Equal(only, CashbackQueues.Classify(cashback));
    }

    // ---- which queue, for the cases that matter ---------------------------

    [Theory]
    [InlineData(Stage.Pending, "validated", CashbackQueue.ReadyToApprove)]
    [InlineData(Stage.Pending, "paid", CashbackQueue.ReadyToApprove)]
    [InlineData(Stage.AwaitingNeverConfirmed, "validated", CashbackQueue.ReadyToApprove)]
    [InlineData(Stage.AwaitingNeverConfirmed, " Validated ", CashbackQueue.ReadyToApprove)]
    [InlineData(Stage.Pending, "pending", CashbackQueue.WaitingOnNetwork)]
    [InlineData(Stage.Pending, "", CashbackQueue.WaitingOnNetwork)]
    [InlineData(Stage.Pending, "something-new", CashbackQueue.WaitingOnNetwork)]
    // Awaiting review but the network went back to pending: still shown, never lost.
    [InlineData(Stage.AwaitingNeverConfirmed, "pending", CashbackQueue.WaitingOnNetwork)]
    [InlineData(Stage.Pending, "rejected", CashbackQueue.NetworkRejected)]
    [InlineData(Stage.Pending, "cancelled", CashbackQueue.NetworkRejected)]
    [InlineData(Stage.AwaitingNeverConfirmed, "canceled", CashbackQueue.NetworkRejected)]
    [InlineData(Stage.AwaitingNeverConfirmed, "REJECTED", CashbackQueue.NetworkRejected)]
    // Taken back by the network before it was ever confirmed.
    [InlineData(Stage.AwaitingNeverConfirmed, "reversed", CashbackQueue.NetworkRejected)]
    // The network reversed money already confirmed: a reversal, whatever it says now.
    [InlineData(Stage.AwaitingAfterConfirmed, "reversed", CashbackQueue.ReversalsToDecide)]
    [InlineData(Stage.AwaitingAfterConfirmed, "rejected", CashbackQueue.ReversalsToDecide)]
    [InlineData(Stage.AwaitingAfterConfirmed, "validated", CashbackQueue.ReversalsToDecide)]
    [InlineData(Stage.Confirmed, "validated", CashbackQueue.History)]
    [InlineData(Stage.Rejected, "rejected", CashbackQueue.History)]
    [InlineData(Stage.Reversed, "reversed", CashbackQueue.History)]
    [InlineData(Stage.PaidOut, "paid", CashbackQueue.History)]
    public void QueueFor(Stage stage, string word, CashbackQueue expected)
    {
        Assert.Equal(expected, CashbackQueues.Classify(Make(stage, word)));
    }

    // ---- overdue ----------------------------------------------------------

    [Theory]
    [InlineData(Stage.Pending, -1, true)]
    [InlineData(Stage.AwaitingNeverConfirmed, -1, true)]
    [InlineData(Stage.AwaitingAfterConfirmed, -1, true)]  // a reversal can be overdue
    [InlineData(Stage.Pending, 1, false)]                 // due tomorrow
    [InlineData(Stage.Confirmed, -30, false)]             // decided cashback is never overdue
    [InlineData(Stage.Rejected, -30, false)]
    [InlineData(Stage.PaidOut, -30, false)]
    public void OverdueMeansUndecidedAndPastDue(Stage stage, int daysFromNow, bool overdue)
    {
        var cashback = Make(stage, "pending", expected: Now.AddDays(daysFromNow));

        Assert.Equal(overdue, CashbackQueues.IsOverdue(cashback, Now));
        Assert.Equal(overdue, CashbackQueues.Overdue(Now).Compile()(cashback));
    }

    // ---- exposure ---------------------------------------------------------

    [Theory]
    [InlineData(Stage.Confirmed, "validated", true)]
    [InlineData(Stage.Confirmed, "pending", true)]
    [InlineData(Stage.Confirmed, "paid", false)]  // the network already paid us
    [InlineData(Stage.Pending, "validated", false)]
    [InlineData(Stage.Rejected, "validated", false)]
    [InlineData(Stage.PaidOut, "validated", false)]
    public void ExposureIsConfirmedMoneyTheNetworkHasNotPaid(Stage stage, string word, bool counted)
    {
        var cashback = Make(stage, word);

        Assert.Equal(counted, CashbackQueues.ConfirmedNotPaidByNetwork.Compile()(cashback));
    }

    // ---- filters ----------------------------------------------------------

    [Fact]
    public void EmptyFilterKeepsEverything()
    {
        var all = new[] { Make(Stage.Pending, "pending"), Make(Stage.Confirmed, "paid") };

        Assert.Equal(2, Apply(all, new CashbackListFilter()).Count);
    }

    [Fact]
    public void QueueAndOldStatusFiltersStillWork()
    {
        var ready = Make(Stage.Pending, "validated");
        var waiting = Make(Stage.Pending, "pending");
        var confirmed = Make(Stage.Confirmed, "validated");
        var all = new[] { ready, waiting, confirmed };

        Assert.Equal(
            new[] { ready },
            Apply(all, new CashbackListFilter { Queue = CashbackQueue.ReadyToApprove }));
        Assert.Equal(
            new[] { confirmed },
            Apply(all, new CashbackListFilter { Status = CashbackStatus.Confirmed }));
        Assert.Equal(
            new[] { ready, waiting },
            Apply(all, new CashbackListFilter { Status = CashbackStatus.Pending }));
    }

    [Fact]
    public void OverdueOnlyKeepsUndecidedPastDue()
    {
        var late = Make(Stage.Pending, "pending", expected: Now.AddDays(-2));
        var onTime = Make(Stage.Pending, "pending", expected: Now.AddDays(2));
        var decided = Make(Stage.Confirmed, "validated", expected: Now.AddDays(-2));

        var result = Apply(
            new[] { late, onTime, decided },
            new CashbackListFilter { OverdueOnly = true, NowUtc = Now });

        Assert.Equal(new[] { late }, result);
    }

    [Theory]
    [InlineData("asha", 1)]            // name
    [InlineData("  ASHA  ", 1)]        // trimmed, any case
    [InlineData("rao@", 0)]            // not part of the name or email
    [InlineData("bala@example", 1)]    // email
    [InlineData("myn", 1)]             // store
    [InlineData("zzz", 0)]
    [InlineData("150", 1)]             // cashback amount
    [InlineData("2499", 1)]            // order amount
    [InlineData("250.00", 1)]          // commission, decimals
    [InlineData("₹2,499", 1)]          // rupee sign and thousands separator
    [InlineData("149", 0)]
    public void SearchMatchesNameEmailStoreOrAmount(string term, int expectedCount)
    {
        var asha = Make(Stage.Pending, "pending", amount: 150m, fullName: "Asha Rao",
            email: "asha@example.com", store: "Myntra", order: 2499m, commission: 250m);
        var bala = Make(Stage.Pending, "pending", amount: 90m, fullName: "Bala K",
            email: "bala@example.com", store: "Ajio", order: 999m, commission: 100m);

        var result = Apply(new[] { asha, bala }, new CashbackListFilter { Search = term });

        Assert.Equal(expectedCount, result.Count);
    }

    [Fact]
    public void SearchSurvivesACashbackWithNoStoreOrAmounts()
    {
        var bare = Make(Stage.Pending, "pending", store: null, order: null, commission: null);

        Assert.Empty(Apply(new[] { bare }, new CashbackListFilter { Search = "myntra" }));
        Assert.Empty(Apply(new[] { bare }, new CashbackListFilter { Search = "999" }));
        Assert.Single(Apply(new[] { bare }, new CashbackListFilter { Search = "asha" }));
    }

    [Fact]
    public void CreatedRangeIsInclusiveAtTheStartAndExclusiveAtTheEnd()
    {
        var day = new DateTime(2026, 10, 10, 0, 0, 0, DateTimeKind.Utc);
        var before = Make(Stage.Pending, "pending", created: day.AddSeconds(-1));
        var atStart = Make(Stage.Pending, "pending", created: day);
        var inside = Make(Stage.Pending, "pending", created: day.AddHours(23));
        var atEnd = Make(Stage.Pending, "pending", created: day.AddDays(1));

        var result = Apply(
            new[] { before, atStart, inside, atEnd },
            new CashbackListFilter { CreatedFrom = day, CreatedBefore = day.AddDays(1) });

        Assert.Equal(new[] { atStart, inside }, result);
    }

    [Fact]
    public void FiltersCombineWithAnd()
    {
        var match = Make(Stage.Pending, "validated", store: "Myntra");
        var wrongQueue = Make(Stage.Pending, "pending", store: "Myntra");
        var wrongStore = Make(Stage.Pending, "validated", store: "Ajio");

        var result = Apply(
            new[] { match, wrongQueue, wrongStore },
            new CashbackListFilter { Queue = CashbackQueue.ReadyToApprove, Search = "myntra" });

        Assert.Equal(new[] { match }, result);
    }

    // ---- summary ----------------------------------------------------------

    [Fact]
    public async Task SummaryAddsUpTheQueues()
    {
        var repository = new Mock<ICashbackRepository>();
        void Count(CashbackQueue queue, int count) =>
            repository.Setup(r => r.CountAsync(
                    It.Is<CashbackListFilter>(f => f.Queue == queue && !f.OverdueOnly),
                    It.IsAny<CancellationToken>()))
                .ReturnsAsync(count);

        Count(CashbackQueue.ReadyToApprove, 4);
        Count(CashbackQueue.ReversalsToDecide, 2);
        Count(CashbackQueue.NetworkRejected, 1);
        Count(CashbackQueue.WaitingOnNetwork, 30);
        Count(CashbackQueue.History, 100);
        repository.Setup(r => r.CountAsync(
                It.Is<CashbackListFilter>(f => f.OverdueOnly && f.Queue == null),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(5);
        repository.Setup(r => r.SumAmountAsync(
                CashbackQueues.ConfirmedNotPaidByNetwork, It.IsAny<CancellationToken>()))
            .ReturnsAsync(1234.50m);

        var summary = await new GetCashbackSummaryQueryHandler(repository.Object)
            .HandleAsync(new GetCashbackSummaryQuery(), CancellationToken.None);

        Assert.Equal(4, summary.ReadyToApprove);
        Assert.Equal(2, summary.ReversalsToDecide);
        Assert.Equal(1, summary.NetworkRejected);
        Assert.Equal(30, summary.WaitingOnNetwork);
        Assert.Equal(100, summary.History);
        Assert.Equal(7, summary.NeedsDecision);
        Assert.Equal(5, summary.Overdue);
        Assert.Equal(1234.50m, summary.ExposureAmount);
    }
}
