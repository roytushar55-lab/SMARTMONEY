# Withdrawals page redesign

Agreed with the owner on 12 October 2026. Same look and approach as the Cashback review page (see `CASHBACK_REVIEW_PLAN.md`). Built one step at a time, each tested and approved before the next. Nothing here is committed.

## Why

The page was a flat 8-column table with seven status chips and a Refresh button: no totals, no search by reference, no date filter, actions only inside the detail dialog, and "needs attention" shown as a tiny icon.

## The plan

- **Summary strip, four tiles:** To decide (count and rupees), To pay (count and rupees owed now), Needs attention, Paid in the last 30 days (rupees).
- **Queue tabs with counts:** To decide (Requested), To pay (Approved; with the manual provider this is where an admin pays and records the bank reference), In progress (Processing), History (Paid, Failed, Declined, Cancelled, with a chip for each). **Needs attention** is a chip over the tabs with its count, like Overdue on the cashback page, not a tab.
- **Search and dates:** user name, email, our reference, provider reference or bank UTR, an amount; a created date range.
- **Cards instead of table rows:** name and email, large amount, "To pay Rs 494.10 after Rs 5.90 fee, UPI, te****@okhdfc", reference with a copy button, age ("Requested 3 h ago", red when an Approved payout has waited too long), a reason in words, an attention note shown on the card (provider error or review note), and actions pinned on the right (below the details on narrow widths). Tapping the card opens the existing detail dialog.
- **Actions on the card (owner chose the recommendation):** Approve and Decline for Requested only. For Approved the card has "Pay..." which opens the detail dialog, because only that has the full destination to copy and the bank reference box. Mark failed and Acknowledge stay in the dialog.
- **Unchanged:** the detail dialog and its action bar; dashboard cards and the sidebar badge keep their links (`WithdrawalsFilter`) and map onto the new tabs.
- **Not planned:** bulk actions (each manual payment needs its own bank reference).

## Steps

| # | Work | State |
|---|---|---|
| 1 | Backend: queue rules, `queue`, `search`, `from`, `to` on the list, a summary endpoint, tests, e2e | **Done 12 Oct** |
| 2 | The page: summary strip, tabs, filters, cards, Approve/Decline on cards; replaces most of the old withdrawals screen tests | **Done 12 Oct** (wide layout seen only in a widget test) |
| 3 | Polish: phone width, empty and error states, deep links from the dashboard and sidebar | **Done 12 Oct** (a walkthrough in the browser pane; nothing needed fixing) |

## Step 1 as built (backend, read-only, no migration)

- **Queue rules** live in one place, `WithdrawalQueues` (Application), as expression trees the database filters with and the tests run in memory; `Classify` uses the compiled expressions. Every status is in exactly one queue: ToDecide = Requested, ToPay = Approved, InProgress = Processing, History = Completed, Failed, Rejected, Cancelled. The attention flag does not move a withdrawal between queues (tested).
- **List** `GET /api/admin/withdrawals` still takes `status`, `needsAttention`, `page`, `pageSize`, and now also `queue` (400 on an unknown name), `search` and `from` / `to`. Search is case-insensitive over user name, email, our reference, the provider reference or bank UTR, plus an exact amount (requested or payout; `Rs` and the rupee sign and thousands commas are ignored). `from` is inclusive and `to` exclusive as UTC instants; a bare date is read as UTC midnight (the page should send the local day start and the next day start, as the cashback page does). Each row now has `queue`, also on the detail response.
- **Summary** `GET /api/admin/withdrawals/summary` (Admin or SuperAdmin): `toDecide`, `toDecideAmount`, `toPay`, `toPayAmount` (the amounts are what the users receive, the net, which is what an admin pays), `inProgress`, `history`, `needsAttention` (any status), `paidLast30Days`, `paidLast30DaysAmount` (Completed, settled in the last 30 days).
- **Code:** `IWithdrawalRepository.ListAdminAsync` and `CountAdminAsync` became `ListAsync(filter)` and `CountAsync(filter)`; new `CountMatchingAsync(predicate)` and `SumNetAmountAsync(predicate)`. `ListAdminWithdrawalsQuery` takes a `WithdrawalListFilter`.
- **Checked:** backend tests 689 (33 new); the e2e script now also checks the summary, queues, search (reference, name, amount, UTR), date range, old status filter and the 400, 401 and 403 cases at each stage of the withdrawal it already runs (167 checks, was 147), against the real database. Not seen on the database: nothing open at the moment, so To decide and To pay are empty there outside the e2e run.
- **The admin app is unchanged** and still works with the new API (extra fields are ignored).

## Step 2 as built (the admin page)

- **Page** (`screens/withdrawals_screen.dart`, one scrolling page): summary strip (To decide with the rupees requested, To pay with the rupees owed now, Needs attention, Paid in the last 30 days with the count), four tabs with counts (To decide is the default), History chips (All settled, Paid, Failed, Declined, Cancelled), search (350 ms pause, or Enter), a date-range button, a "Needs attention (n)" chip, Clear filters, Refresh in the header (reloads list and numbers). A failed summary only turns the tiles into dashes.
- **Card** (`widgets/withdrawal_card.dart`): name and email, status badge (and a "Needs attention" badge), the payout line ("To pay Rs 244.10, after Rs 5.90 fee, UPI, se****@okhdfc"), a reason in words, an amber note with the review note or provider error on flagged cards, the reference with a copy button, "Requested 2 min ago" (red and bold once a Requested or Approved one has waited over 24 hours, unless a payment provider has it), the request time, the amount, and the action on the right (under the details below 760 px). **Requested:** Approve and Decline right on the card, with the same confirmation, wording and reason dialog as the detail dialog (results as a snackbar). **Approved:** "Pay..." which opens the detail dialog (the whole destination and the bank reference box are only there). **Flagged:** "Review...". Processing, handed-to-provider and settled cards have no button. Tapping the card opens the detail dialog, which is unchanged.
- **Deep links** (`WithdrawalsFilter` is unchanged): Requested opens To decide, Approved opens To pay, Processing opens In progress, a settled status opens History on that chip, and "needs attention" with no status shows every flagged withdrawal across the tabs (each card then says which queue it is in); turning that chip off returns to To decide.
- **Words** in `withdrawal_queues.dart` (`WithdrawalQueue`, `withdrawalReason`, `withdrawalAttentionNote`, `withdrawalAgeText`, `withdrawalIsWaitingLong`); model gains `queue` and `AdminWithdrawalSummary`; service gains `queue`, `search`, `from`, `to` and `summary()`.
- **Shared widgets (new, in `lib/core/`):** `AdminSummaryTile` and `AdminSummaryStrip`, `AdminQueueTab` and `AdminQueueTabBar`, `AdminSearchField`, and `money_and_dates.dart` (`formatRupeesGrouped`, `formatDateRangeLabel`, `formatAgo`). The cashback page was moved onto them with no change in behaviour (all its tests pass unchanged).
- **Tests:** admin 289 (was 255). The old table-based screen tests were rewritten (`withdrawals_screen_test.dart`, `withdrawals_screen_deep_link_test.dart`, same coverage plus the new features: counts, tiles, tabs, chips, search, attention, empty and error states, deep links, every button rule, approve and decline on the card, 409 and 400 handling, one request while busy, copy reference, wide and phone layout); the dialog and flow tests only needed their helpers changed (the fake backend now answers `queue` and the summary, and the helpers open the right tab instead of an "All" chip).
- **Checked in the browser pane** (release build, phone width, owner's session, looked only, no decision made): the summary numbers, tabs with counts, a Requested card with Approve and Decline, an Approved bank-transfer card with Pay..., and Pay... opening the detail dialog with the full account to copy. Seed data: 3 Requested and 2 Approved withdrawals from throwaway e2e accounts are now in the owner's database (left as they are; delete or settle them as you like).
- **Not seen in the browser:** the wide card layout (the pane is about 800 px wide; a widget test covers the buttons at the right edge), the date picker, a flagged card (nothing is flagged in the database), the overdue red age.
- **Not done / left for step 3:** polish pass (phone width, empty and error states looked at in the browser, deep links from the dashboard and sidebar looked at in the browser).

## Step 3 as done (polish walkthrough, no code change)

Looked at in the browser pane (release build, phone width, the owner's session, nothing decided), against the real database with the 3 Requested and 2 Approved seed withdrawals:

- **Dashboard link:** the "Approved, not yet paid" card opens the To pay tab; its numbers (0 needs attention, 3 waiting, 2 approved) match the page's tiles and tab counts.
- **Empty state:** the In progress tab (0) shows "Nothing is with a payment provider right now."
- **Search:** typing part of a reference in To pay sent one request after the pause (`queue=ToPay&search=...`, 200) and left only that card; Clear filters and the attention chip appeared.
- **Error state:** with the API stopped, Refresh shows "Something went wrong. Can't reach the server. Check your connection and try again." with Try again, the filters kept; with the API back, Try again returned the list.
- **Phone width:** the strip goes two by two, the tabs scroll sideways, the card puts the amount and buttons under the details; no overflow. The search hint was shortened ("Search name, reference, UTR, amount") because it was cut off on a narrow screen.
- **Not seen in the browser:** the wide layout, the date picker, a flagged card (nothing is flagged in the database and a flag needs a provider event), the red overdue age, the sidebar's own link and badge (unchanged code, covered by tests). All are covered by widget tests.

The redesign is finished. Nothing is committed.

---

# HANDOFF: start here (written for step 2; the redesign is now finished)

**Next task: none in this plan. (Steps 2 and 3 are done, see "Step 2 as built" and "Step 3 as done" above.)** The notes below were written for step 2 and are kept for the working agreements.

*(Old line:)* step 3, polish. (Step 2 is done, see "Step 2 as built" above; the rest of this handoff was written for step 2.)**

*(Original step 2 handoff:)* step 2, the page (`admin/lib/features/withdrawals/screens/withdrawals_screen.dart`, 402 lines, a table). Build it the way the cashback page was built (`cashback_review_screen.dart`, `widgets/cashback_card.dart`, `cashback_queues.dart`: the server names the queue, the app only labels and colours it; one scrolling `CustomScrollView`; summary strip, tabs with counts, search with a 350 ms pause, date range, an overdue-style chip for attention, cards that go two-column at 760 px).

- Keep `WithdrawalsScreen({service, initialFilter, onChanged})` and `WithdrawalsFilter` working: the dashboard cards, the sidebar badge (`WithdrawalAttentionCounter`) and `withdrawals_screen_deep_link_test.dart` rely on them. Map `status: Requested` to To decide, `Approved` to To pay, `Processing` to In progress, a settled status to History on that chip, and `needsAttentionOnly` to the attention chip.
- Approve and Decline on Requested cards reuse `withdrawal_actions.dart` and `withdrawal_action_bar.dart` (the same confirmations and reason dialog as the detail dialog); after any action call `widget.onChanged` and reload the list and the summary. "Pay..." opens `showWithdrawalDetailDialog`.
- Existing tests to rewrite: `withdrawals_screen_test.dart`, `withdrawals_screen_deep_link_test.dart`; the detail dialog tests should not need changes.
- To look at it in the browser pane you need open withdrawals: the real database has none right now. Seed some with the e2e account (`e2e-user-...` request a withdrawal; minimum Rs 250 and the user needs available balance), and do not decide anything with the owner's signed-in session; the pane is signed in as their SuperAdmin.
- The pane is about 800 px wide, so the two-column card layout (760 px of card, about 1100 px of window) cannot be seen there; cover it with a widget test and tell the owner.
- Working agreements: one step at a time, stop for approval; keep replies short; say what was not verified; `dart format` only your own files; no migration is needed.

Test counts now: backend 689, admin 289, e2e 167 checks.
