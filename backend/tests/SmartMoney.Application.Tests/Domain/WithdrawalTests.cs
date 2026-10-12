using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Tests.Domain;

public sealed class WithdrawalTests
{
    private static Withdrawal New(decimal amount = 400m, decimal fee = 4m, decimal userFee = 2m) =>
        new(Guid.NewGuid(), Guid.NewGuid(), "WD1", amount, fee, userFee,
            PayoutMethod.Upi, "as****@okhdfc", "protected");

    private static Withdrawal Approved()
    {
        var w = New();
        w.Approve(Guid.NewGuid());
        return w;
    }

    private static Withdrawal Processing()
    {
        var w = Approved();
        w.MarkSubmitted("Test", "P1");
        return w;
    }

    // ---- creation ------------------------------------------------------

    [Fact]
    public void New_withdrawal_is_requested_open_and_nets_the_user_fee_off()
    {
        var w = New();

        Assert.Equal(WithdrawalStatus.Requested, w.Status);
        Assert.True(w.IsOpen);
        Assert.Equal(398m, w.NetAmount);
        Assert.Equal("protected", w.DestinationProtected);
    }

    [Theory]
    [InlineData(0, 0, 0)]
    [InlineData(-1, 0, 0)]
    [InlineData(100, 5, 6)]   // user fee above total fee
    [InlineData(100, -1, 0)]
    [InlineData(100, 100, 100)] // nothing left to pay out
    public void Invalid_money_is_refused(decimal amount, decimal fee, decimal userFee)
    {
        Assert.Throws<ArgumentException>(() => New(amount, fee, userFee));
    }

    [Fact]
    public void Destination_and_reference_are_required()
    {
        Assert.Throws<ArgumentException>(() => new Withdrawal(
            Guid.NewGuid(), Guid.NewGuid(), " ", 400m, 0m, 0m,
            PayoutMethod.Upi, "m", "p"));
        Assert.Throws<ArgumentException>(() => new Withdrawal(
            Guid.NewGuid(), Guid.NewGuid(), "WD", 400m, 0m, 0m,
            PayoutMethod.Upi, "m", ""));
    }

    [Fact]
    public void References_are_unique_letters_and_digits_with_a_date()
    {
        var date = new DateTime(2026, 10, 11, 0, 0, 0, DateTimeKind.Utc);
        var refs = Enumerable.Range(0, 200).Select(_ => Withdrawal.NewReference(date)).ToList();

        Assert.Equal(refs.Count, refs.Distinct().Count());
        Assert.All(refs, r =>
        {
            Assert.StartsWith("WD20261011", r);
            Assert.Equal(20, r.Length);
            Assert.True(r.All(char.IsAsciiLetterOrDigit));
        });
    }

    // ---- approve / reject / cancel -------------------------------------

    [Fact]
    public void Approve_records_the_reviewer_and_only_works_once()
    {
        var w = New();
        Guid admin = Guid.NewGuid();

        w.Approve(admin);

        Assert.Equal(WithdrawalStatus.Approved, w.Status);
        Assert.Equal(admin, w.ReviewedByUserId);
        Assert.NotNull(w.ApprovedAt);
        Assert.Throws<InvalidOperationException>(() => w.Approve(admin));
    }

    [Fact]
    public void Automatic_approval_has_no_reviewer()
    {
        var w = New();

        w.Approve(null);

        Assert.Null(w.ReviewedByUserId);
    }

    [Fact]
    public void Reject_needs_a_reason_wipes_the_destination_and_is_final()
    {
        var w = New();

        Assert.Throws<ArgumentException>(() => w.Reject(Guid.NewGuid(), "  "));
        w.Reject(Guid.NewGuid(), "Name mismatch");

        Assert.Equal(WithdrawalStatus.Rejected, w.Status);
        Assert.Equal("Name mismatch", w.FailureReason);
        Assert.Null(w.DestinationProtected);
        Assert.True(w.IsTerminal);
        Assert.NotNull(w.SettledAt);
    }

    [Fact]
    public void Reject_works_on_approved_but_not_on_processing()
    {
        Approved().Reject(Guid.NewGuid(), "no");

        Assert.Throws<InvalidOperationException>(
            () => Processing().Reject(Guid.NewGuid(), "no"));
    }

    [Fact]
    public void Cancel_only_before_approval()
    {
        var w = New();
        w.Cancel();
        Assert.Equal(WithdrawalStatus.Cancelled, w.Status);
        Assert.Null(w.DestinationProtected);

        Assert.Throws<InvalidOperationException>(() => Approved().Cancel());
    }

    // ---- submission ----------------------------------------------------

    [Fact]
    public void Submitted_moves_to_processing_and_counts_the_attempt()
    {
        var w = Approved();

        w.MarkSubmitted(" Test ", " P1 ");

        Assert.Equal(WithdrawalStatus.Processing, w.Status);
        Assert.Equal("Test", w.ProviderName);
        Assert.Equal("P1", w.ProviderReference);
        Assert.Equal(1, w.SubmissionAttempts);
        Assert.NotNull(w.SubmittedAt);
        Assert.NotNull(w.DestinationProtected); // still needed until settled
    }

    [Fact]
    public void Begin_submission_marks_it_as_started_without_changing_status_or_count()
    {
        var w = Approved();
        Assert.False(w.SubmissionStarted);

        w.BeginSubmission(" Test ");

        Assert.True(w.SubmissionStarted);
        Assert.Equal(WithdrawalStatus.Approved, w.Status);
        Assert.Equal("Test", w.ProviderName);
        Assert.Equal(0, w.SubmissionAttempts);
        Assert.NotNull(w.SubmittedAt);
    }

    [Fact]
    public void Begin_submission_keeps_the_first_start_time_and_needs_an_approved_withdrawal()
    {
        var w = Approved();
        w.BeginSubmission("Test");
        DateTime first = w.SubmittedAt!.Value;
        Thread.Sleep(5);

        w.BeginSubmission("Test");
        w.MarkSubmitted("Test", "P1");

        Assert.Equal(first, w.SubmittedAt);
        Assert.Throws<InvalidOperationException>(() => New().BeginSubmission("Test"));
        Assert.Throws<ArgumentException>(() => Approved().BeginSubmission(" "));
    }

    [Fact]
    public void A_failed_attempt_also_counts_as_started()
    {
        var w = Approved();

        w.RecordSubmissionFailure("Test", "timeout");

        Assert.True(w.SubmissionStarted);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(2)]
    public void Reaching_a_final_state_clears_the_attention_flag(int how)
    {
        var w = Processing();
        w.FlagNeedsAttention("check");

        switch (how)
        {
            case 0: w.Complete("U", null); break;
            case 1: w.Fail("x"); break;
            default:
                var requested = New();
                requested.FlagNeedsAttention("check");
                requested.Reject(Guid.NewGuid(), "no");
                w = requested;
                break;
        }

        Assert.False(w.NeedsAttention);
    }

    [Fact]
    public void Only_approved_withdrawals_can_be_submitted()
    {
        Assert.Throws<InvalidOperationException>(() => New().MarkSubmitted("T", null));
        Assert.Throws<InvalidOperationException>(() => Processing().MarkSubmitted("T", null));
    }

    [Fact]
    public void Temporary_failure_keeps_it_approved_and_stores_the_error()
    {
        var w = Approved();

        w.RecordSubmissionFailure("Test", "timeout");
        w.RecordSubmissionFailure("Test", "timeout again");

        Assert.Equal(WithdrawalStatus.Approved, w.Status);
        Assert.Equal(2, w.SubmissionAttempts);
        Assert.Equal("timeout again", w.LastError);
        Assert.Null(w.FailureReason);
    }

    // ---- complete / fail -----------------------------------------------

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Complete_from_approved_or_processing_keeps_the_reference_and_wipes_details(
        bool submittedFirst)
    {
        var w = submittedFirst ? Processing() : Approved();

        w.Complete(" UTR9 ", 1.5m);

        Assert.Equal(WithdrawalStatus.Completed, w.Status);
        Assert.Equal("UTR9", w.ProviderReference);
        Assert.Equal(1.5m, w.ActualProviderFee);
        Assert.Null(w.DestinationProtected);
        Assert.NotNull(w.SettledAt);
    }

    [Fact]
    public void Complete_twice_or_from_requested_is_refused()
    {
        var w = Processing();
        w.Complete("U", null);

        Assert.Throws<InvalidOperationException>(() => w.Complete("U", null));
        Assert.Throws<InvalidOperationException>(() => New().Complete("U", null));
    }

    [Fact]
    public void Complete_refuses_a_negative_provider_fee()
    {
        Assert.Throws<ArgumentException>(() => Processing().Complete("U", -1m));
    }

    [Fact]
    public void Fail_keeps_the_user_reason_and_the_internal_detail_apart()
    {
        var w = Processing();

        w.Fail("Could not be paid.", "BENE_ACCOUNT_CLOSED");

        Assert.Equal(WithdrawalStatus.Failed, w.Status);
        Assert.Equal("Could not be paid.", w.FailureReason);
        Assert.Equal("BENE_ACCOUNT_CLOSED", w.LastError);
        Assert.Null(w.DestinationProtected);
    }

    [Fact]
    public void Fail_needs_a_reason_and_a_started_payout()
    {
        Assert.Throws<ArgumentException>(() => Approved().Fail(" "));
        Assert.Throws<InvalidOperationException>(() => New().Fail("x"));
    }

    [Fact]
    public void Terminal_states_accept_no_further_transitions()
    {
        var w = Processing();
        w.Fail("x");

        Assert.Throws<InvalidOperationException>(() => w.Approve(null));
        Assert.Throws<InvalidOperationException>(() => w.Cancel());
        Assert.Throws<InvalidOperationException>(() => w.Reject(Guid.NewGuid(), "x"));
        Assert.Throws<InvalidOperationException>(() => w.Complete("U", null));
        Assert.Throws<InvalidOperationException>(() => w.Fail("again"));
    }

    // ---- attention flag ------------------------------------------------

    [Fact]
    public void Flag_and_clear_needs_attention_appends_notes_and_trims_long_text()
    {
        var w = New();

        w.FlagNeedsAttention("first");
        w.FlagNeedsAttention(new string('x', 900));

        Assert.True(w.NeedsAttention);
        Assert.StartsWith("first | ", w.ReviewNote);
        Assert.Equal(500, w.ReviewNote!.Length);

        w.ClearNeedsAttention();
        Assert.False(w.NeedsAttention);
    }

    [Fact]
    public void Flagging_the_same_reason_again_changes_nothing()
    {
        var w = New();

        w.FlagNeedsAttention("Stored destination is unreadable.");
        for (int i = 0; i < 20; i++)
        {
            w.FlagNeedsAttention("Stored destination is unreadable.");
        }

        Assert.Equal("Stored destination is unreadable.", w.ReviewNote);
    }

    [Fact]
    public void A_different_reason_is_still_added_and_a_cleared_flag_can_be_raised_again()
    {
        var w = New();
        w.FlagNeedsAttention("first");
        w.FlagNeedsAttention("second");
        Assert.Equal("first | second", w.ReviewNote);

        w.ClearNeedsAttention();
        w.FlagNeedsAttention("first");

        // After an admin cleared it, the same reason is a new occurrence and is noted again.
        Assert.True(w.NeedsAttention);
        Assert.Equal("first | second | first", w.ReviewNote);
    }

    [Fact]
    public void Status_check_moves_the_timestamp_and_can_note_an_error()
    {
        var w = Processing();
        DateTime? before = w.UpdatedAt;
        Thread.Sleep(5);

        w.RecordStatusCheck("unreachable");

        Assert.True(w.UpdatedAt > before);
        Assert.Equal("unreachable", w.LastError);
        Assert.Equal(WithdrawalStatus.Processing, w.Status);
    }
}
