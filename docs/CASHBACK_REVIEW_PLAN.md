# Cashback review: rearrangement and risk plan

Agreed with the owner on 12 October 2026. Built one step at a time, each tested and approved before the next.

## Decisions (final)

1. **Approve gate:** an admin can approve only when the network says **validated** (or paid). Pending, rejected, cancelled and reversed are refused.
2. **Override:** allowed, with a required reason, restricted to SuperAdmin, and recorded.
3. **Paid out:** drop the per-cashback "Withdrawn" timeline step and the Paid out tab (a withdrawal covers wallet money, not single sales). Show wallet-level withdrawn instead.
4. **Reversal after the user withdrew:** do not refuse. Debit what is available, record the rest as **owed**, offset it against future cashback, and block withdrawals until it is cleared. The Terms need a line about this.

## The new page (step 3 and 4)

Summary strip (needs a decision, waiting on network, overdue, confirmed but not yet paid by the network in rupees), then queues instead of raw status chips: Ready to approve, Reversals to decide, Network rejected, Waiting on network, Overdue, History. Each row shows the reason in words and has its actions pinned at the right. Search by user, store or amount, date filters, a detail panel with the timeline, reason dialogs for reject and reverse, bulk approve in Ready to approve.

## Steps

| # | Work | State |
|---|---|---|
| 1 | Audit events (`CashbackEvents`), reviewer and reason on every decision | **Done 12 Oct, migration applied to the owner database and verified** |
| 2 | Approve gate on validated, override with reason | **Done 12 Oct** (no migration needed) |
| 3 | New page: summary, queues, filters, pinned actions, reason text | **Done 12 Oct** (part 1 backend, part 2 the admin page; wide layout seen only in a widget test) |
| 4 | Detail panel with timeline, reason dialogs (reason becomes required for reject and reverse), bulk approve | **4a and 4b done 12 Oct** (required reasons and dialogs; detail dialog with the history); 4c bulk approve not started |
| 5 | Commission changes follow the network; late validated after a rejection goes back to review | not started |
| 6 | Stale-sales job and dashboard card | not started |
| 7 | Paid-out removal (decision 3) and the exposure figure | not started |
| 8 | Reversal shortfall policy (decision 4) | not started |

Left out for now: email notices, a second-approver rule above a limit.

## Step 1 as built

- Domain: `CashbackEvent` (immutable) and `CashbackEventType` (Created, NetworkStatusChanged, FlaggedForReview, Approved, Rejected, Reversed). Reason is trimmed, blank means none, at most 500 characters.
- Approve, reject and reverse commands now carry `ReviewerId` (from the signed-in admin's token) and an optional `Reason`, and write one event in the same save as the wallet change. The endpoints take an optional JSON body `{ "reason": "..." }`; the admin app does not send one yet, so the reason is still optional.
- Ingestion writes events with no actor: Created, FlaggedForReview, and NetworkStatusChanged whenever the network's status for a sale actually changes (replays and case-only differences are ignored).
- `GET /api/admin/cashbacks/{id}/events` returns the trail oldest first with the acting admin's name and email.
- `CashbackRepository.GetByIdAsync` now loads the conversion so a decision records the network status it was made against.
- Migration `20261012094719_AddCashbackEvents` only creates one table and its indexes; nothing existing changes. **Applied to the owner database on 12 Oct at their request.** Verified: a sale through the webhook produced Created, NetworkStatusChanged, FlaggedForReview, then Approved with the admin and reason; a body-less approve still works; a 501-character reason gets 400; the events endpoint gives 404 for an unknown cashback and 403 for a normal user; the 89-check e2e run still passes.
- Tests: 491 backend tests pass (19 new).

## Step 2 as built

- **Rule** (`CashbackApprovalPolicy`, backend): approving is allowed only when the network status is `validated` or `paid`. Pending, rejected, cancelled, reversed, an unknown word, or no status at all are refused with a plain message (409). The rule applies to anything an admin can decide on, so approving a review-queue row whose network says rejected or reversed is refused too. Reject and Reverse are not gated.
- **Override:** `POST /api/admin/cashbacks/{id}/approve` with `{ "override": true, "reason": "..." }`. A reason is required (400 without one) and only a SuperAdmin may use it (403 for a plain Admin). It is recorded as event type `ApprovedByOverride` with the actor, reason and the network status it went against. An override on a sale the network has already validated is treated as a normal approval. Re-approving a confirmed cashback that the network now calls reversed also needs the override, and still credits the wallet only once.
- **Admin app:** `cashback_approval_rules.dart` mirrors the rule. On each row Approve is enabled only when the rule allows it; a normal Admin sees it disabled with the reason as a tooltip; a SuperAdmin sees an amber "Approve anyway…" button that asks for a reason. `approve()` in the service takes `reason` and `override`. The screen takes an optional service and role for tests.
- **Tests:** backend 518 (27 new), admin 191 (9 new), e2e run 111 checks (22 new in section 10: pending approval refused, override needs a reason, a plain Admin gets 403, a SuperAdmin override is recorded in the trail).
- **Checked in the browser pane** against the test API on the real database: validated and paid rows show Approve, pending and reversed rows show "Approve anyway…".
- **Not done on purpose:** the page still has the old layout and the reason is still optional for normal approve, reject and reverse. Those come in steps 3 and 4.

## Step 3, part 1 as built (backend, read-only, no migration)

- **Queue rules** live in one place, `CashbackQueues` (Application). They are expression trees, so the database filters with them and the tests run the same rules over in-memory objects; `Classify` uses the compiled expressions, so a row's queue and the queue's count cannot disagree. Every cashback is in exactly one queue (a test checks every stage against eleven network words).
- **Queues**, in precedence order: *ReversalsToDecide* (AwaitingAdminReview with a confirmed date); *NetworkRejected* (undecided, never confirmed, network `rejected`, `cancelled`, `canceled` or **`reversed`**); *ReadyToApprove* (undecided, never confirmed, network `validated` or `paid`); *WaitingOnNetwork* (every other undecided one, so none is ever lost); *History* (Confirmed, Rejected, Reversed, PaidOut). Two deliberate differences from the brief: a never-confirmed sale the network calls **reversed** goes to Network rejected (the first live check found it sitting in Waiting, where nobody would decide it), and Waiting also holds an under-review sale whose network status went back to pending.
- **Overdue** is a flag, not a queue: undecided and `expectedConfirmationDate` in the past. Each list row has `queue` and `isOverdue`.
- **List** `GET /api/admin/cashbacks` takes, besides `status`, `page`, `pageSize` (all still work): `queue`, `overdue=true`, `search`, `from`, `to`. Search is case-insensitive over user name, email and store name, plus an exact amount (cashback, order or commission; `₹` and thousands commas are ignored). `from` is inclusive and `to` exclusive, as UTC instants; a bare date is read as UTC midnight, so the page should send the local day's start and the next day's start. Filters combine with "and". An unknown queue is 400. No store filter (search by store name covers it).
- **Summary** `GET /api/admin/cashbacks/summary`: `readyToApprove`, `reversalsToDecide`, `networkRejected`, `waitingOnNetwork`, `history`, `needsDecision` (ready + reversals + rejected; overdue is not added), `overdue`, `exposureAmount` (Confirmed cashback whose network status is not `paid`). Admin or SuperAdmin only.
- **Code:** `ICashbackRepository.ListByStatusAsync` and `CountByStatusAsync` became `ListAsync(filter)`, `CountAsync(filter)` and `SumAmountAsync(predicate)`.
- **Checked:** 647 backend tests (129 new, includes the old list tests rewritten for the filter); the e2e script has a new section 11 (128 checks, was 111); a separate read-only script against the real database confirmed the SQL translation: queue counts equal the summary and add up to the total, search by email, name, store and amount, `%` searched literally, date range, future range empty, overdue count, bad queue 400, 401 and 403. **Not checked on the database:** a non-zero overdue count (nothing is overdue yet; covered by unit tests only).
- **Admin app:** unchanged by part 1.

## Step 3, part 2 as built (the admin page)

Owner's design answers: **cards with the actions on the right, and status chips inside History.** Not answered, so left as it was: "Needs a decision" does **not** count Overdue.

- **Page** (`cashback_review_screen.dart`, one scrolling page): summary strip (needs a decision, waiting on network, overdue, "confirmed, not paid by network" in rupees, each with a hover hint), queue tabs with counts (Ready to approve is the default), History chips (All decided, Confirmed, Rejected, Reversed), then search (350 ms pause, or Enter), a date-range button, an Overdue chip with its count, and Clear filters. A failed summary only turns the tiles into "—"; the list still works.
- **Card** (`widgets/cashback_card.dart`): name and email, store, order, commission, created date, the network word as a coloured badge, our status once decided, an Overdue badge, a one-line reason in words, and "Due in 12 days" or "Overdue by 3 days". At card width 760 and up the amount and the buttons are pinned on the right; below that they sit under the details. Approve, "Approve anyway…" (SuperAdmin) and Reject or Reverse behave exactly as in step 2. Decided cashback has no buttons.
- **Words and colours** are in `cashback_queues.dart` (`CashbackQueue`, `cashbackReason`, `cashbackDueText`). The server decides the queue; the app only names it.
- **Dashboard cards** still link with a raw status: Pending and Awaiting review show every cashback with that status across the queues (a removable chip, and each card says which queue it is in); Confirmed, Rejected, Reversed and Paid out open History on that status.
- **Dates:** the picker is in the viewer's local days, sent as the start of the first day and the start of the day after the last, as UTC instants.
- **Tests:** admin 222 (31 new: tabs, counts, strip, search pause and Enter, overdue, clear filters, deep links, card contents, buttons at the right edge on a wide screen, no overflow on a 400 px phone, deciding reloads list and numbers, the wording, the due-date maths, the date query).
- **Checked in the browser pane** (release build, phone width, owner's session, looked and searched only, no decision buttons): the dashboard deep link, summary numbers and tab counts, cards with reasons and buttons, a real search request after the pause. **Not seen in the browser:** the wide card layout (the pane is about 800 px wide, the card needs about 1100) and the date picker. The wide layout is covered by a widget test only; please look at it on a normal monitor.
- **Left for step 4:** the detail panel with the timeline, reason dialogs (reason required for reject and reverse), bulk approve. Left for step 7: removing the Paid out status from the dashboard card and the History chips.

## Step 4, part 4a as built (required reasons)

Step 4 is split in three: **4a** required reasons and reason dialogs (done), **4b** the detail panel with the timeline, **4c** bulk approve in Ready to approve.

- **Backend:** `RejectCashbackCommand` and `ReverseCashbackCommand` can no longer be built without a reason (`ArgumentException`, which the controller already answers with 400 and the message). The reason is trimmed; over 500 characters is still 400 from the controller. A missing body, an empty string and whitespace are all refused. Approve is unchanged: the reason stays optional, and required only for the SuperAdmin override.
- **Admin app:** Reject and Reverse open a reason dialog (the same one "Approve anyway" uses) in place of the yes/no confirmation; an empty reason is refused in the dialog and nothing is sent; Cancel sends nothing. The service sends `{"reason": ...}` for both. Plain Approve keeps its confirmation.
- **Tests:** backend 656 (9 new); admin 235 (13 new); e2e 147 checks (19 new, section 12: a real reversal through the Reversals to decide queue, refused without a reason three ways, money does not move while refused, reason kept trimmed in the trail, reject the same, rejecting twice is 409).
- **Browser pane:** opened the Reject dialog on a real card, pressed Reject with the box empty (refused with "A reason is required to reject a cashback.", no request sent), then Cancel. A reason was not submitted there: the pane is signed in as the owner. The submit path is covered by the e2e run and the widget tests.
- **Side change:** the removable status chip now ends in "×" instead of a glyph that needed a fallback font.

## Step 4, part 4b as built (detail dialog with the history)

- **Opening it:** tap anywhere on a cashback card (it has a small "Details ›" hint). The buttons on the card keep their own taps and do not open it. It is a dialog, like the withdrawal detail, not a side panel; read only, with Close.
- **Content** (`screens/cashback_detail_dialog.dart`): a coloured note on top (queue badge, network badge, overdue badge, the reason in words, what approving needs while the network has not validated, due or overdue text), the numbers (user, email, store, order, commission, cashback, created, expected by, confirmed), then the **History**. The numbers come from the list row and show at once; only the history is loaded, from the existing `GET /api/admin/cashbacks/{id}/events` (no backend change). A failed load shows the message and Try again, with the numbers still visible; an empty trail says history only exists from when the audit trail was introduced.
- **History lines** (`cashback_event_copy.dart`), oldest first: what happened (Created from the network report, Network changed its status, Sent for review, Approved, Approved anyway (override), Rejected, Reversed; an unknown type shows its raw name), who ("by the network", or "by Name (email)"), the status change ("Pending to Awaiting review", only when it moved), what the network said, the amount, the time, and the admin's reason in a quote box.
- **Tests:** admin 255 (20 new: summary content, confirmed date only when present, approving note, overdue text, every event type and the wording, oldest first, override and reversal reasons, unknown type, empty and failed trail with retry, phone width with long text, Close, opening from a card, a button not opening it, the blank-field parsing). Two layout bugs found by them and fixed: the loading and error placeholders were too short.
- **Browser pane** (owner's session, looked only): opened the e2e rejection on a real card; the summary, then the history showed Created by the network and Rejected by the named admin with the quoted reason. The dialog has no decision buttons, so nothing was decided.
- **Not done:** deciding from inside the dialog (an admin closes it and uses the card). Easy to add later if wanted.

---

# HANDOFF: start here (written 12 October 2026, end of step 2; step 3 part 1 added after)

**Next task: step 4c, bulk approve in Ready to approve.** Steps 3, 4a and 4b are done in full (see the "as built" sections above; the "Step 3 brief" below is the original brief and is finished). Nothing from this work is committed (see "State of the repo"). Expected test counts now: backend 656, admin 255, e2e 147 checks.

## Working agreements (do not break)

- One step at a time, then stop for the owner's approval (memory note `work-in-steps-not-all-at-once`). Step 3 is big: propose a short numbered sub-plan first (backend list and summary changes, then the page), do the first part, report, stop.
- Never apply a database migration without asking. Step 3 should need none; it only reads.
- Never touch the owner's own API on port 7056 if it is running there; test against a copy (see "How to run and verify").
- Never sign out of, or act with, the owner's admin account in the browser pane. The pane keeps a persistent session signed in as `tushar1@gmail.com`, their real SuperAdmin. Look, but do not click decision buttons with it. Drive actions through the API (curl, the simulator, the e2e script) and use the pane only to look.
- Keep replies short and plain. Say clearly what was not verified.

## What is already true (steps 1 and 2)

- Every cashback has an audit trail (`CashbackEvents`): Created, NetworkStatusChanged, FlaggedForReview, Approved, ApprovedByOverride, Rejected, Reversed, each with actor, reason, from and to status, amount and the network status at the time. Read it with `GET /api/admin/cashbacks/{id}/events`.
- Approve is refused unless the network status is `validated` or `paid` (`CashbackApprovalPolicy`). A SuperAdmin may send `{ "override": true, "reason": "..." }`. The admin page already mirrors this per row (`admin/lib/features/cashbacks/cashback_approval_rules.dart`).
- Reason is optional for normal approve, reject and reverse; step 4 makes it required for reject and reverse.
- Status meanings: `Pending` = created from a network "pending" report, money in the user's pending bucket. `AwaitingAdminReview` = a decisive network status (validated, rejected, cancelled, reversed) parked it for a human; it may or may not have been confirmed before (`confirmedDate` set means it was, and the money is already available). `Confirmed`, `Rejected`, `Reversed` and `PaidOut` are final (PaidOut is never set; decision 3 removes it in step 7).
- The network status "paid" never changes a cashback; it only updates the conversion.

## Step 3 brief: the new page

Current page: `admin/lib/features/cashbacks/screens/cashback_review_screen.dart` (about 450 lines). One flat `AdminStickyTable`, six status chips (Awaiting review, Pending, Confirmed, Rejected, Reversed, Paid out), eight columns, and the action buttons are at the far right so you must scroll sideways to reach them. Backend list: `GET /api/admin/cashbacks?status=&page=&pageSize=` (`AdminCashbacksController.List`, `ListCashbacksQueryHandler`, `ICashbackRepository.ListByStatusAsync`) returns `AdminCashbackListItemResponse` (user, store, amounts, status, networkStatus, dates, confirmedDate).

Build in this order:

1. **Backend: queues and summary.** Add a `queue` filter to the list and a summary endpoint, both read-only. Queues should be mutually exclusive, in this precedence:
   - *Reversals to decide*: status AwaitingAdminReview and `confirmedDate` not null (the network reversed something already confirmed).
   - *Network rejected*: status Pending or AwaitingAdminReview, network status rejected, cancelled or canceled.
   - *Ready to approve*: status Pending or AwaitingAdminReview, network status validated or paid.
   - *Waiting on network*: status Pending, any other network status (normally pending).
   - *History*: Confirmed, Rejected, Reversed, PaidOut.
   - *Overdue* is an overlay, not a queue: undecided (Pending or AwaitingAdminReview) and `expectedConfirmationDate` in the past. Show it as a count and a filter chip.
   Also add search (user name or email, store name, amount), a date range on the created date, and optionally store. Summary: the count per queue, the overdue count, and **exposure** = total amount of Confirmed cashbacks whose conversion network status is not `paid` (confirmed money the network has not paid you yet). Keep the old `status` filter working, because the dashboard cards deep-link with a raw status (`DashboardScreen.onOpenReviewQueue`).
2. **Admin app: the page.** A summary strip (needs a decision = Ready plus Reversals plus Network rejected, waiting on network, overdue, exposure in rupees), queue tabs replacing the status chips, a search box and a date filter. Each row shows user and store, order, commission and cashback, the network status badge, age and due date (overdue highlighted), a one-line reason in words (reuse the rules file wording, for example "Network says validated, safe to approve"), and **actions pinned where they never scroll away**. Consider a card or list layout on narrow widths instead of the wide table; the browser pane is often phone width. The disabled Approve with tooltip and the SuperAdmin "Approve anyway…" must keep working exactly as now.
3. **Tests:** backend handler tests for each queue's membership and the summary; admin widget tests for tabs, counts, search and the pinned actions; extend the e2e script (`backend/tools/e2e/run.mjs`) if the API surface changes.
4. Left for step 4: the detail panel with the timeline, the reason dialogs, bulk approve.

Open design points to settle with the owner while planning: card layout versus table; whether History needs its own status chips; whether "needs a decision" should also count Overdue.

## How to run and verify

- Backend tests: `cd backend; dotnet test tests/SmartMoney.Application.Tests` (expect 518 passed). Admin: `cd admin; flutter analyze; flutter test` (expect no issues, 191 passed). Mobile is unchanged (107). Simulator: `node --test backend/tools/affiliate-simulator/ui/simulator.test.mjs` (24). End to end: `node backend/tools/e2e/run.mjs` from `backend/` (expect 111 checks passed; it builds its own API on port 7156 against the configured database and leaves two throwaway accounts).
- Browser pane: `backend/.claude/launch.json` has `smartmoney-backend-test` (safe API on 7056, console OTP, no real email), `smartmoney-backend-real` (real SMTP, reads `tools/e2e/overrides.cmd`), `smartmoney-admin` (5180) and `smartmoney-mobile` (8088), the last two in release mode. Traps are in memory `admin-web-verify-in-user-browser`: debug mode is blank; the served bundle stays the OLD one until the release compile finishes (poll `main.dart.js` for a string you just added, remembering that dart2js escapes non-ASCII characters such as the ellipsis); the pane caches bundles (refetch with cache reload, then reload); a background tab does not paint (call `tabs_select`); click by coordinates, since Flutter exposes no accessibility tree.
- Seeding sales without the UI: use the simulator in `backend/tools/affiliate-simulator/ui` or `curl` the Cuelinks webhook (`POST /api/webhooks/cuelinks`, header `X-Webhook-Token`, token `local-test-token` when the API was started with `start-api.cmd`). Create a click as a test user first (`POST /api/affiliate/clicks`, then `GET /r/{token}` without following the redirect to read the `subid`). Seed one sale per queue with the statuses pending, validated, rejected, cancelled, reversed (approve a validated one first, then send reversed) and paid. Overdue depends on a past `expectedConfirmationDate`, which the network share window sets in the future, so cover Overdue with a unit test.
- Shell traps on this machine: heredocs containing apostrophes break (use the Write and Edit tools); files may have CRLF endings, so multi-line string replacements must normalise them; run `dart format` only on your own files; `dotnet build` fails while a test API is running and locking `src/SmartMoney.Api/bin` (stop it first, or build into a temp folder with `-o`).

## Test accounts in the owner's database (passwords are test values)

| Account | Password | Role |
|---|---|---|
| `e2e-admin-20261012102049@example.com` | `E2e@Admin12345` | SuperAdmin (newest throwaway; older pairs `...20261011153650` also exist) |
| `e2e-user-20261012102049@example.com` | `E2e@Pass12345` | user |
| `roytushar55@gmail.com` | password set during testing, deliberately not written here (the owner should change it) | user |

Two sales were seeded for the visual check under `e2e-user-20261012102049` (one pending, `VIS-PENDING-1`, one validated, `VIS-VALID-1`), plus whatever the e2e runs created. They are clearly named test data.

## State of the repo

Everything from the withdrawals work, the simulator tool, the e2e tool and steps 1 and 2 is **uncommitted** on branch `dev`. The owner has not asked for a commit. A sensible split when asked: (1) backend withdrawals with migrations and tests, (2) cashback audit trail and approval gate (backend, migration `AddCashbackEvents`, tests), (3) admin app changes, (4) mobile, (5) tools and docs. Migrations applied to the owner's database so far: `AddWithdrawals` and `AddCashbackEvents`.

## Open items elsewhere (not part of this plan)

The production startup check (run the API with `ASPNETCORE_ENVIRONMENT=Production` and the data protection settings; a runner script was written but never run), the closure payout for balances under Rs 250, email notices, Terms and Privacy still naming Cashfree, and forgot-password answering 200 for a deactivated account. See `docs/WITHDRAWAL_HANDOFF.md` sections 7 and 10.
