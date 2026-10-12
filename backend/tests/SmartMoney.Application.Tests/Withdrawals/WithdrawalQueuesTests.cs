using Moq;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawalSummary;
using SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Withdrawals;

/// <summary>
/// The queue rules and list filters are expression trees the database runs;
/// these tests run the very same expressions over in-memory objects.
/// </summary>
public sealed class WithdrawalQueuesTests
{
    private static readonly DateTime Now = new(2026, 10, 12, 12, 0, 0, DateTimeKind.Utc);

    private static void Set(object entity, string property, object? value)
    {
        entity.GetType().GetProperty(property)!.SetValue(entity, value);
    }

    private static Withdrawal Make(
        WithdrawalStatus status,
        decimal amount = 500m,
        decimal userFee = 5.90m,
        string reference = "WD20261012AAAA",
        string fullName = "Asha Rao",
        string email = "asha@example.com",
        string? providerReference = null,
        DateTime? created = null,
        DateTime? settled = null,
        bool needsAttention = false)
    {
        var user = new User(fullName, email, "9999999999", "hash", Guid.NewGuid());
        var withdrawal = new Withdrawal(
            user.Id, Guid.NewGuid(), reference, amount, userFee + 2m, userFee,
            PayoutMethod.Upi, "as****@okhdfc", "protected");

        switch (status)
        {
            case WithdrawalStatus.Approved:
                withdrawal.Approve(Guid.NewGuid());
                break;
            case WithdrawalStatus.Processing:
                withdrawal.Approve(Guid.NewGuid());
                withdrawal.MarkSubmitted("Cashfree", providerReference);
                break;
            case WithdrawalStatus.Completed:
                withdrawal.Approve(Guid.NewGuid());
                withdrawal.Complete(providerReference, null);
                break;
            case WithdrawalStatus.Failed:
                withdrawal.Approve(Guid.NewGuid());
                withdrawal.Fail("Bank refused it");
                break;
            case WithdrawalStatus.Rejected:
                withdrawal.Reject(Guid.NewGuid(), "Not allowed");
                break;
            case WithdrawalStatus.Cancelled:
                withdrawal.Cancel();
                break;
        }

        if (needsAttention)
        {
            withdrawal.FlagNeedsAttention("Provider says paid");
        }

        Set(withdrawal, nameof(Withdrawal.User), user);

        if (created is not null)
        {
            Set(withdrawal, nameof(Withdrawal.CreatedAt), created.Value);
        }

        if (settled is not null)
        {
            Set(withdrawal, nameof(Withdrawal.SettledAt), settled.Value);
        }

        return withdrawal;
    }

    private static List<Withdrawal> Apply(
        IEnumerable<Withdrawal> withdrawals,
        WithdrawalListFilter filter)
    {
        IQueryable<Withdrawal> query = withdrawals.AsQueryable();

        foreach (var predicate in filter.Predicates())
        {
            query = query.Where(predicate);
        }

        return query.ToList();
    }

    // ---- every withdrawal is in exactly one queue -------------------------

    [Theory]
    [InlineData(WithdrawalStatus.Requested, WithdrawalQueue.ToDecide)]
    [InlineData(WithdrawalStatus.Approved, WithdrawalQueue.ToPay)]
    [InlineData(WithdrawalStatus.Processing, WithdrawalQueue.InProgress)]
    [InlineData(WithdrawalStatus.Completed, WithdrawalQueue.History)]
    [InlineData(WithdrawalStatus.Failed, WithdrawalQueue.History)]
    [InlineData(WithdrawalStatus.Rejected, WithdrawalQueue.History)]
    [InlineData(WithdrawalStatus.Cancelled, WithdrawalQueue.History)]
    public void EveryStatusIsInExactlyOneQueue_AndClassifyAgrees(
        WithdrawalStatus status, WithdrawalQueue expected)
    {
        var withdrawal = Make(status);

        var matching = Enum.GetValues<WithdrawalQueue>()
            .Where(queue => WithdrawalQueues.Matches(queue).Compile()(withdrawal))
            .ToList();

        Assert.Equal(expected, Assert.Single(matching));
        Assert.Equal(expected, WithdrawalQueues.Classify(withdrawal));
    }

    [Fact]
    public void TheAttentionFlagDoesNotMoveItBetweenQueues()
    {
        foreach (var status in Enum.GetValues<WithdrawalStatus>())
        {
            var plain = Make(status);
            var flagged = Make(status, needsAttention: true);

            Assert.Equal(WithdrawalQueues.Classify(plain), WithdrawalQueues.Classify(flagged));
            Assert.False(WithdrawalQueues.NeedsAttention.Compile()(plain));
            Assert.True(WithdrawalQueues.NeedsAttention.Compile()(flagged));
        }
    }

    [Fact]
    public void EveryStatusIsCoveredByAQueue()
    {
        // A new status added later must be put in a queue on purpose.
        foreach (var status in Enum.GetValues<WithdrawalStatus>())
        {
            Assert.True(
                Enum.IsDefined(WithdrawalQueues.Classify(Make(status))),
                status.ToString());
        }
    }

    // ---- paid lately ------------------------------------------------------

    [Theory]
    [InlineData(WithdrawalStatus.Completed, -5, true)]
    [InlineData(WithdrawalStatus.Completed, -30, true)]    // exactly on the line counts
    [InlineData(WithdrawalStatus.Completed, -31, false)]
    [InlineData(WithdrawalStatus.Failed, -1, false)]
    [InlineData(WithdrawalStatus.Rejected, -1, false)]
    [InlineData(WithdrawalStatus.Cancelled, -1, false)]
    public void PaidSinceCountsOnlyPayoutsInTheWindow(
        WithdrawalStatus status, int settledDaysAgo, bool counted)
    {
        var since = Now.AddDays(-30);
        var withdrawal = Make(status, settled: Now.AddDays(settledDaysAgo));

        Assert.Equal(counted, WithdrawalQueues.PaidSince(since).Compile()(withdrawal));
    }

    [Fact]
    public void AnOpenWithdrawalIsNeverPaidSince()
    {
        Assert.False(WithdrawalQueues.PaidSince(Now.AddDays(-30)).Compile()(Make(WithdrawalStatus.Approved)));
    }

    // ---- filters ----------------------------------------------------------

    [Fact]
    public void EmptyFilterKeepsEverything()
    {
        var all = new[] { Make(WithdrawalStatus.Requested), Make(WithdrawalStatus.Completed) };

        Assert.Equal(2, Apply(all, new WithdrawalListFilter()).Count);
    }

    [Fact]
    public void QueueStatusAndAttentionFiltersWork()
    {
        var requested = Make(WithdrawalStatus.Requested);
        var approved = Make(WithdrawalStatus.Approved, needsAttention: true);
        var paid = Make(WithdrawalStatus.Completed);
        var all = new[] { requested, approved, paid };

        Assert.Equal(new[] { requested }, Apply(all, new WithdrawalListFilter { Queue = WithdrawalQueue.ToDecide }));
        Assert.Equal(new[] { paid }, Apply(all, new WithdrawalListFilter { Queue = WithdrawalQueue.History }));
        Assert.Equal(new[] { paid }, Apply(all, new WithdrawalListFilter { Status = WithdrawalStatus.Completed }));
        Assert.Equal(new[] { approved }, Apply(all, new WithdrawalListFilter { NeedsAttentionOnly = true }));
        Assert.Empty(Apply(all, new WithdrawalListFilter
        {
            NeedsAttentionOnly = true,
            Queue = WithdrawalQueue.ToDecide
        }));
    }

    [Theory]
    [InlineData("asha", 1)]              // name
    [InlineData("  ASHA  ", 1)]          // trimmed, any case
    [InlineData("bala@example", 1)]      // email
    [InlineData("wd20261012aaaa", 1)]    // our reference, any case
    [InlineData("utr9876", 1)]           // the bank UTR
    [InlineData("zzz", 0)]
    [InlineData("500", 1)]               // requested amount
    [InlineData("494.10", 1)]            // payout amount
    [InlineData("₹494.10", 1)]
    [InlineData("1,200", 1)]             // thousands separator, other row
    [InlineData("499", 0)]
    public void SearchMatchesNameEmailReferenceUtrOrAmount(string term, int expectedCount)
    {
        var asha = Make(
            WithdrawalStatus.Completed, amount: 500m, userFee: 5.90m,
            reference: "WD20261012AAAA", fullName: "Asha Rao",
            email: "asha@example.com", providerReference: "UTR9876543");
        var bala = Make(
            WithdrawalStatus.Requested, amount: 1200m, userFee: 10m,
            reference: "WD20261012BBBB", fullName: "Bala K",
            email: "bala@example.com");

        var result = Apply(new[] { asha, bala }, new WithdrawalListFilter { Search = term });

        Assert.Equal(expectedCount, result.Count);
    }

    [Fact]
    public void SearchSurvivesAWithdrawalWithNoProviderReference()
    {
        var bare = Make(WithdrawalStatus.Requested);

        Assert.Empty(Apply(new[] { bare }, new WithdrawalListFilter { Search = "utr" }));
        Assert.Single(Apply(new[] { bare }, new WithdrawalListFilter { Search = "asha" }));
    }

    [Fact]
    public void CreatedRangeIsInclusiveAtTheStartAndExclusiveAtTheEnd()
    {
        var day = new DateTime(2026, 10, 10, 0, 0, 0, DateTimeKind.Utc);
        var before = Make(WithdrawalStatus.Requested, created: day.AddSeconds(-1));
        var atStart = Make(WithdrawalStatus.Requested, created: day);
        var inside = Make(WithdrawalStatus.Requested, created: day.AddHours(23));
        var atEnd = Make(WithdrawalStatus.Requested, created: day.AddDays(1));

        var result = Apply(
            new[] { before, atStart, inside, atEnd },
            new WithdrawalListFilter { CreatedFrom = day, CreatedBefore = day.AddDays(1) });

        Assert.Equal(new[] { atStart, inside }, result);
    }

    [Fact]
    public void FiltersCombineWithAnd()
    {
        var match = Make(WithdrawalStatus.Approved, fullName: "Asha Rao");
        var wrongQueue = Make(WithdrawalStatus.Requested, fullName: "Asha Rao");
        var wrongName = Make(WithdrawalStatus.Approved, fullName: "Bala K", email: "bala@example.com");

        var result = Apply(
            new[] { match, wrongQueue, wrongName },
            new WithdrawalListFilter { Queue = WithdrawalQueue.ToPay, Search = "asha" });

        Assert.Equal(new[] { match }, result);
    }

    // ---- summary ----------------------------------------------------------

    [Fact]
    public async Task SummaryAssemblesTheCountsAndAmounts()
    {
        var repository = new Mock<IWithdrawalRepository>();
        void Count(WithdrawalQueue queue, int count) =>
            repository.Setup(r => r.CountMatchingAsync(
                    WithdrawalQueues.Matches(queue), It.IsAny<CancellationToken>()))
                .ReturnsAsync(count);

        Count(WithdrawalQueue.ToDecide, 3);
        Count(WithdrawalQueue.ToPay, 2);
        Count(WithdrawalQueue.InProgress, 1);
        Count(WithdrawalQueue.History, 40);
        repository.Setup(r => r.SumNetAmountAsync(
                WithdrawalQueues.Matches(WithdrawalQueue.ToDecide), It.IsAny<CancellationToken>()))
            .ReturnsAsync(1500.50m);
        repository.Setup(r => r.SumNetAmountAsync(
                WithdrawalQueues.Matches(WithdrawalQueue.ToPay), It.IsAny<CancellationToken>()))
            .ReturnsAsync(988.20m);
        repository.Setup(r => r.CountMatchingAsync(
                WithdrawalQueues.NeedsAttention, It.IsAny<CancellationToken>()))
            .ReturnsAsync(4);
        // The "paid lately" rule is built fresh with the current time, so match on any other rule.
        repository.Setup(r => r.CountMatchingAsync(
                It.Is<System.Linq.Expressions.Expression<Func<Withdrawal, bool>>>(e =>
                    e != WithdrawalQueues.NeedsAttention
                    && e != WithdrawalQueues.Matches(WithdrawalQueue.ToDecide)
                    && e != WithdrawalQueues.Matches(WithdrawalQueue.ToPay)
                    && e != WithdrawalQueues.Matches(WithdrawalQueue.InProgress)
                    && e != WithdrawalQueues.Matches(WithdrawalQueue.History)),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(12);
        repository.Setup(r => r.SumNetAmountAsync(
                It.Is<System.Linq.Expressions.Expression<Func<Withdrawal, bool>>>(e =>
                    e != WithdrawalQueues.Matches(WithdrawalQueue.ToDecide)
                    && e != WithdrawalQueues.Matches(WithdrawalQueue.ToPay)),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(6000m);

        var summary = await new GetAdminWithdrawalSummaryQueryHandler(repository.Object)
            .HandleAsync(new GetAdminWithdrawalSummaryQuery(), CancellationToken.None);

        Assert.Equal(3, summary.ToDecide);
        Assert.Equal(1500.50m, summary.ToDecideAmount);
        Assert.Equal(2, summary.ToPay);
        Assert.Equal(988.20m, summary.ToPayAmount);
        Assert.Equal(1, summary.InProgress);
        Assert.Equal(40, summary.History);
        Assert.Equal(4, summary.NeedsAttention);
        Assert.Equal(12, summary.PaidLast30Days);
        Assert.Equal(6000m, summary.PaidLast30DaysAmount);
    }
}
