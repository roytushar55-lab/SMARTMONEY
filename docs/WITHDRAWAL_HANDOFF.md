# Withdrawals: Handoff

**Read this first when starting a new session.**
**Written:** 11 October 2026. **Branch:** `dev` (last commit `c07d28e`). **Nothing from this work is committed.**

## 0. The one-paragraph status

The **backend** for user withdrawals is finished, reviewed, tested and **applied to the owner's database**. It works with any payout vendor; until one exists the **Manual** provider lets an admin pay by hand and record the bank reference. The **admin app** is complete for withdrawals: all 5 steps (data layer, list, detail dialog, actions, dashboard cards plus sidebar badge) are done, **awaiting the owner's visual check of step 5**. The **mobile app has no withdrawal work yet** and shows wrong labels for the new ledger entries (see section 6).

| Area | State | Tests |
|---|---|---|
| Backend (`backend/`) | Done, uncommitted. Migration `AddWithdrawals` applied on 11 Oct | 472 pass |
| Admin app (`admin/`) | Steps 1-5 of 5 done, uncommitted; verified in the browser pane on 11 Oct (dashboard cards, list, detail, approve, mark paid) | 182 pass, analyzer clean |
| Mobile app (`smart_money_mobile/`) | All 3 steps done (ledger labels + held balance; withdraw flow; history, detail and cancel), uncommitted; verified in the browser pane on 11 Oct (request, held line, history, cancel, paid) | 107 pass, analyzer clean |
| Docs | Provider guide and manual test checklist written | n/a |

## 1. Start here (first five minutes)

1. `git status` (expect many uncommitted files, listed in section 9) and `git log --oneline -1` (expect `c07d28e`).
2. Run the tests to confirm the baseline:
   - `cd backend; dotnet test tests/SmartMoney.Application.Tests` (expect 472 passed)
   - `cd admin; flutter analyze; flutter test` (expect no issues, 182 passed)
   - `cd smart_money_mobile; flutter analyze; flutter test` (expect no issues, 107 passed)
   - `cd backend; node tools/e2e/run.mjs` (expect 89 checks passed; it builds and runs its own API on port 7156 against the configured database and leaves two throwaway accounts, see `tools/e2e/README.md`)
3. Read sections 2, 7 and 8, then ask the owner whether they have checked admin step 5 (section 5) and the mobile screens (section 6) in their browser, and what comes next: probably committing (section 9 suggests a split), then the open items in section 7.

### Working agreements with the owner (do not break these)
- **Build in steps, one at a time.** Propose a short numbered plan, do one step, verify, report, **stop and wait for approval**.
- **Verify Flutter screens yourself in the embedded browser pane** (the owner asked for this on 11 Oct). Use `backend/.claude/launch.json`: `smartmoney-backend-test` (safe env overrides via `tools/e2e/start-api.cmd`, port 7056; check nothing of the owner's is already on 7056), `smartmoney-admin` (5180) and `smartmoney-mobile` (8088), both **release mode**. Debug mode shows a blank page in the pane (its debug client cannot open a WebSocket). The pane may cache an old `main.dart.js`; refetch it with `cache: 'reload'` and reload. Sign in with the end-to-end run's throwaway accounts.
- **Never apply database migrations or touch the owner's real config without asking.** Test with environment-variable overrides (section 8), never by editing user secrets.
- **Commit only when asked.**
- Keep replies short and plain; say clearly when something was not verified.

## 2. Decisions already made (do not re-open)

| Topic | Decision |
|---|---|
| Minimum / maximum | Rs 250 (Terms of Service) / Rs 50,000 default. The cap is a placeholder safety value, owner to confirm |
| Fee | Provider fee = (flat + percent of amount) plus 18% tax. User pays 50%, deducted from the payout; SmartMoney pays the rest. Defaults charge nothing until a vendor's real price is set |
| Approval | Admin approval required by default (`RequireAdminApproval = true`) |
| Open withdrawals | One per user at a time |
| Re-authentication | User sends their password to request a withdrawal |
| Money handling | Request moves available to **held**. Paid: held to TotalWithdrawn. Failed, declined or cancelled: held back to available |
| Bank details | Stored encrypted plus a masked copy. The encrypted copy is wiped when the withdrawal reaches any final state |
| Idempotency | Each withdrawal has a unique `Reference` (like `WD20261011K7QM2XA9PD`), sent to the provider as the idempotency key |
| Provider selection | `Payouts:Provider`. "Manual" default. "Fake" allowed in Development only. Unknown name is a startup error |
| Delete account | Refused while money is held, and while any available balance remains |
| Provider failure text | User sees a plain message. The provider's raw text goes to an admin-only field (`LastError`) |
| **Provider owns it** | Once a send to an automatic provider has started, an admin may decline, mark paid or mark failed **only when it needs attention or its retries ran out**. Stops paying a user twice (provider and admin) or paying and refunding |
| Attempt marker | `Withdrawal.BeginSubmission` is saved **before** the provider is called, so a concurrent decline loses the concurrency check instead of racing a payout |
| Contradictions | A provider report that contradicts our records (success after a refund, failure after a payment) is **never applied**; it flags the withdrawal for an admin |
| Admin UI buttons | Hide buttons the backend will certainly refuse; let the server judge the rest and show its plain-language message |

## 3. Backend map (`backend/src`)

**Domain:** `Entities/Withdrawal.cs` (state machine), `Wallet.cs` (`HeldBalance`, `HoldForWithdrawal`, `CompleteWithdrawal`, `ReleaseWithdrawalHold`), `WalletTransaction.cs` (`HeldBalanceAfter`, `WithdrawalId`), enums `WithdrawalStatus` (Requested, Approved, Processing, Completed, Failed, Rejected, Cancelled), `PayoutMethod` (Upi, BankTransfer), ledger types `WithdrawalRequested`, `WithdrawalCompleted`, `WithdrawalReleased`.

**Application:**
- `Abstractions/Payouts/` the vendor contract: `IPayoutProvider`, `PayoutContracts.cs` (`PayoutWebhookRequest` carries `RawBody` bytes; verify signatures over those), `IPayoutDestinationProtector`.
- `Common/PayoutOptions.cs`, `PayoutPolicy.cs` (limits and fee maths).
- `Features/Withdrawals/`: `WithdrawalSettlement` (the only code that finishes a withdrawal; does not save), `WithdrawalRules` (eligibility and destination validation), `WithdrawalProcessor` (`SubmitAsync`, `ReconcileAsync`, `ListPendingAsync`), `WithdrawalAdminSupport` (the "provider owns it" guards), `WithdrawalDecisions`, and one folder per use case (Request, Cancel, Preview, GetMy, GetMyList, ListAdmin, GetAdmin, Approve, Reject, MarkPaid, MarkFailed, Acknowledge, ProcessPayoutWebhook).

**Infrastructure:** `Payouts/` (`ManualPayoutProvider`, `FakePayoutProvider` for Development, `DataProtectionPayoutDestinationProtector`, `PayoutProviders.cs` = **the one place a vendor is registered**, `PayoutStartupValidator`, `WithdrawalWorker`), `Persistence/` (`WithdrawalRepository`, `WithdrawalConfiguration`, migration `20261011114124_AddWithdrawals` with the scaffolded `xmin` column removed by hand because it is a Postgres system column).

**Api:** `WithdrawalsController`, `AdminWithdrawalsController`, `PayoutWebhooksController`, rate-limit policy `withdrawal` in `Program.cs`.

### Endpoints
- User (`[Authorize]`): `GET /api/withdrawals`, `GET /api/withdrawals/preview?amount=`, `GET /api/withdrawals/{id}`, `POST /api/withdrawals`, `POST /api/withdrawals/{id}/cancel`. `GET /api/wallet` now returns `heldBalance`.
- Admin (`Admin,SuperAdmin`): `GET /api/admin/withdrawals?status=&needsAttention=&page=&pageSize=`, `GET /api/admin/withdrawals/{id}` (full destination only while open; `Cache-Control: no-store`), `POST /api/admin/withdrawals/{id}/approve|reject|mark-paid|mark-failed|acknowledge`. Not found returns 404, refused state 409, bad input 400.
- Webhook (anonymous): `POST /api/webhooks/payouts/{provider}`. 200 applied, duplicate, ignored or flagged; 400 bad signature or body; 404 not the active provider; 413 over 64 KB; 503 so the provider retries.

### Config (`appsettings.json`)
`Payouts:` Provider, MinimumAmount 250, MaximumAmount 50000, FlatFee 0, PercentFee 0, FeeTaxPercent 18, UserFeeSharePercent 50, RequireAdminApproval true, MaxOpenWithdrawalsPerUser 1, MaxSubmissionAttempts 5, WorkerIntervalSeconds 60, WorkerBatchSize 25, ReconcileAfterMinutes 15, `Fake:Behavior` (Success, Pending, Reject, TemporaryFailure). `DataProtection:` KeysPath, CertificatePath, CertificatePassword, UseDpapi, AllowUnencryptedKeys. `RateLimiting:WithdrawalRequestsPerTenMinutes` 10 (per IP; the limiter runs before authentication so per-user is not possible).

### Production startup requirements (the app refuses to start without them)
Outside Development: `DataProtection:KeysPath` set to a persistent folder **and** key encryption (`CertificatePath` + `CertificatePassword`, or `UseDpapi=true` on Windows, or the explicit opt-out `AllowUnencryptedKeys=true`). Replacing the certificate makes existing key files unreadable (only the configured certificate decrypts), so settle open withdrawals first or extend `DependencyInjection.cs` with `UnprotectKeysWithAnyCertificate`.

### How to add a real vendor
Read `backend/docs/PAYOUT_PROVIDER_GUIDE.md`: one adapter class implementing `IPayoutProvider`, one line in `PayoutProviders.Catalog`, config, tests. Before switching from Manual, settle every Approved or Processing withdrawal (an automatic worker would submit Approved ones that an admin may already have paid by hand).

## 4. Admin app map (`admin/lib/features/withdrawals/`)

| File | Role |
|---|---|
| `models/admin_withdrawal.dart` | `AdminWithdrawal` (with `isOpen`), `AdminWithdrawalDestination`, `AdminWithdrawalPage`, `WithdrawalDecision` |
| `services/admin_withdrawal_api_service.dart` | list, get, approve, reject, markPaid, markFailed, acknowledge |
| `withdrawal_status_copy.dart` | status labels and colours (Completed shows as "Paid", Rejected as "Declined"), filter list, method labels |
| `withdrawal_formatters.dart` | `formatRupees`, `formatDateTime` (local time) |
| `withdrawal_actions.dart` | `WithdrawalActions.of(w)`: which buttons to offer (the "provider owns it" rule) |
| `screens/withdrawals_screen.dart` | list: status chips (starts on Requested, plus All), Needs attention toggle, table, pager, Refresh; row tap opens the dialog; reloads after changes |
| `screens/withdrawal_detail_dialog.dart` | detail: banners, Pay to (copy buttons), Amounts, User, Timeline, Payment; loads the detail endpoint every time |
| `screens/withdrawal_action_bar.dart` | footer buttons, two-phase ask-then-send, result banner, busy state |
| `screens/withdrawal_input_dialog.dart` | reason or bank-reference prompt (required, trimmed, length limits) |
| `withdrawals_filter.dart` | `WithdrawalsFilter` (status or every status, needs-attention only) with constants `requested`, `approved`, `needsAttention`; the list opens on one and the dashboard deep-links with one |
| `withdrawal_attention_counter.dart` | `WithdrawalAttentionCounter`, a `ValueNotifier<int?>` for the sidebar badge: `refresh()` reads `totalCount` of the needs-attention list with `pageSize=1`; a failed refresh keeps the last number |
| `features/shell/admin_shell.dart` | Existing file: the "Withdrawals" sidebar entry with a red count badge, owns the counter (refreshed on every navigation and after any withdrawal action, no timer), deep-links the dashboard into the list |
| `features/dashboard/screens/dashboard_screen.dart` | Existing file: a "Withdrawals" section with three tappable cards (Needs attention, Waiting for approval, Approved not yet paid); services are now injectable for tests |

Tests are in `admin/test/features/withdrawals/`; `withdrawal_test_support.dart` has the row fixture and `FakeWithdrawalServer`, `fake_withdrawal_backend.dart` is a stateful fake API.

## 5. Admin step 5 (dashboard cards and sidebar badge): done 11 Oct, not yet seen by the owner

What was built (tests: `test/features/dashboard/dashboard_screen_test.dart`, `test/features/withdrawals/withdrawal_attention_counter_test.dart`, `test/features/withdrawals/withdrawals_screen_deep_link_test.dart`):
- Dashboard: a "Withdrawals" section under the cashback pipeline with three cards, each from the list endpoint with `pageSize=1`: Needs attention (red), Waiting for approval (Requested, amber), Approved not yet paid (blue). Tapping one opens the Withdrawals list on that filter through `onOpenWithdrawals(WithdrawalsFilter)`, mirroring the cashback deep link (`key: ValueKey(filter)` so the screen restarts on the new filter).
- Sidebar: a red count pill on "Withdrawals" when any withdrawal needs attention (shows `99+` above 99). Driven by `WithdrawalAttentionCounter`, owned by the shell.
- Refresh policy chosen without the owner (confirm it): the badge refreshes on shell start, on every sidebar or dashboard navigation, and after any withdrawal action (`WithdrawalsScreen.onChanged`). No timer, so a flag raised by the worker or a webhook while the admin sits on one screen appears on their next click. Add a periodic refresh if the owner wants it.
- `WithdrawalsScreen` takes `initialFilter` (default `WithdrawalsFilter.requested`) and `onChanged`.

Owner to check after a hot restart: the dashboard section and card taps, the badge (the test user in section 9 has no flagged withdrawals, so the badge is hidden unless one is flagged), and the three-card row on a phone-width window.

## 6. Mobile app: all 3 steps done on 11 Oct, not yet seen by the owner

Plan: (1) ledger labels plus held-balance line **(done)**; (2) withdraw flow: amount, `GET /api/withdrawals/preview`, UPI or bank form, password, result **(done)**; (3) history and detail with cancel while Requested, plain status copy, and the server's 409 messages **(done)**.

**Step 3, what was built** (`lib/features/withdrawals/`, tests in `test/withdrawals/`):
- `data/models/withdrawal_page.dart`, `data/models/withdrawal_decision.dart`; `WithdrawalApiService.list(page)`, `get(id)`, `cancel(id)`.
- `presentation/withdrawal_status_copy.dart`: `WithdrawalStatusCopy.forStatus` gives a badge label, a tone and a one-line explanation per status (Completed = "Paid", Rejected = "Declined", unknown = "In progress"; failed, declined and cancelled all say the money is back in the wallet), plus `withdrawalMethodLabel` and local-time date formatters.
- `screens/withdrawals_screen.dart` (`WithdrawalsScreen`, route `RouteNames.withdrawals`): newest first, pull to refresh, "Load more" while `hasNextPage`, a row opens the detail; pops `true` if a cancel happened inside (also on system back).
- `screens/withdrawal_details_screen.dart` (`WithdrawalDetailsScreen`, route `RouteNames.withdrawalDetails` with a `Withdrawal` argument): opens with the list's copy then fetches `GET /{id}` (a failed fetch keeps the copy); shows status, explanation, amount, fee, net ("Paid" once Completed), destination, method, reference, requested and settled times, bank reference, failure reason; "Cancel withdrawal" only while `canCancel`, behind a confirm dialog; success shows a snackbar, refetches and pops `true`; a 409 or 404 shows the message and refetches so the new status appears.
- `wallet_screen.dart`: the "Bank Account" placeholder button is **replaced by "History"**, which opens the list and reloads the wallet when it reports a change. Nothing was planned behind Bank Account; tell the owner.

Owner to check after a hot restart: wallet tab > History (the test user in section 9 has 15 withdrawals), open a few, and cancel a Requested one (request one first via Withdraw; the wallet should show the money back).

**Step 2, what was built** (`smart_money_mobile/lib/features/withdrawals/`, tests in `test/withdrawals/`, `withdrawal_test_support.dart` has `FakeWithdrawalServer` with a `standard()` fake that answers previews and posts):
- `data/models/withdrawal_preview.dart` (`WithdrawalPreview`), `data/models/withdrawal.dart` (`Withdrawal`, mirrors `WithdrawalResponse`, ready for step 3), `data/services/withdrawal_api_service.dart` (`preview(amount)`, `request(...)`, enum `PayoutMethod`). `AuthorizedApiClient` gained `postJson` (decodes the reply, server `message` on errors).
- `presentation/screens/withdraw_screen.dart` (`WithdrawScreen`, route `RouteNames.withdraw`, pops `true` after a success, also on system back): on open it previews amount 0 to show "Available · Min · Max" and a "Use full balance" shortcut; typing an amount previews it after a 400 ms pause (fee, "You'll receive", or the server's refusal in amber; a failed preview says so but does not block); "Pay to" is a UPI / Bank transfer segmented control with name plus UPI ID, or account number plus IFSC; the password field; the button reads "Withdraw ₹X". Local validation copies the server's shapes (UPI, 9-18 digit account, IFSC) and limits; 400 and 409 messages are shown as the server sends them, and a 409 re-fetches the limits and the preview. Success shows amount, fee, net, masked destination and the reference, with "Done".
- `wallet_screen.dart`: the Withdraw button opens the route and reloads the wallet when it returns `true`. The "Bank Account" button still says "coming soon" (no feature planned behind it; consider removing it).

Owner to check after a hot restart: open Withdraw from the wallet tab, try an amount under ₹250 and over the balance, both payout methods, a wrong password, and a real request (the backend is on Manual, so it lands in the admin app as Requested).

**Step 1, what was built** (`smart_money_mobile/lib/features/wallet/`, tests in `test/wallet/`, `wallet_test_support.dart` has the fake token storage and a fake wallet service):
- `wallet_transaction_copy.dart`: `WalletMoneyDirection { added, removed, moved }` replaces the credit/debit bool. `WithdrawalRequested` = "Withdrawal requested", removed (minus). `WithdrawalCompleted` = "Withdrawal paid", moved (no sign, neutral colour, tick icon: the money already left available when requested, a second minus would double count). `WithdrawalReleased` = "Withdrawal returned", added (plus). Unknown types are now neutral "Wallet update" instead of a green plus.
- `wallet_summary.dart`: `heldBalance` (0 when the field is missing).
- `wallet_screen.dart`: the balance card shows "₹X on hold for a withdrawal" under the available amount whenever held > 0; `WalletScreen` takes an optional `service` for tests. The "Withdraw" button still shows "coming soon" until step 2.

Owner to check after a hot restart: the wallet tab with the test user from section 9 (it has 0 held, so the held line is hidden; its ledger has withdrawal entries of all three kinds).

**Step 2 notes:** the request needs the user's password (`POST /api/withdrawals` body `RequestWithdrawalRequest`: `amount`, `method` "Upi" or "BankTransfer", `beneficiaryName`, then `upiId` or `bankAccountNumber` plus `ifscCode`, and `password`), one open withdrawal per user, minimum Rs 250, the server's 409 messages are plain language and should be shown as they are. The preview endpoint returns the fee split and net amount for a given amount.

## 7. Open items and known gaps

**Product and docs**
- **Closure payout:** the legal documents promise a one-time payout for balances under Rs 250 when an account is closed. The delete flow does not do that, and nothing builds it.
- **Email notices** for withdrawal events (requested, paid, failed) are not built.
- **Privacy Policy and Terms still name Cashfree**; update them and the stored consent version (`ConsentPolicy`, currently `2026-10-05`) once a vendor is chosen.
- **`docs/MILESTONES.md` is stale on M4** (it says blocked); the backend is built, only the vendor is missing.
- Fee numbers and the Rs 50,000 cap need real values once a vendor and a business decision exist.

**Code**
- A manual "paid" records the approving admin only, not who recorded the payment.
- Cashback reversal cannot take money that is held for a withdrawal (it now says so clearly); reversal against held money would need a negative-balance policy, out of scope.
- The existing cashback review screen's pager has the same phone-width overflow I fixed in the withdrawals list (not touched).
- The HTTP endpoints were exercised end to end by script on 11 Oct (see section 9) but have no automated integration tests; the only automated wiring check builds the real DI container and constructs the controllers.
- Retries have no exponential backoff (every worker pass, up to `MaxSubmissionAttempts`).

## 8. Environment and gotchas

- **The owner's user secrets contain real values:** a real SMTP config (`Email:Host`), a real super admin (`Seed:SuperAdminEmail`), the DB connection string and the Cuelinks webhook token. Starting the API and registering test users sends **real emails** unless you override. Use **environment variables for that run only** (they beat user secrets), in a `.cmd` file (quoting `set` inside `launch.json` got mangled): `Email__Host=" "` (console OTP sender, codes print to the log), `Email__Password=disabled-for-test` (fail-safe), `Seed__SuperAdminEmail=<throwaway>`, plus any `Payouts__*` or `RateLimiting__*`. See `backend/docs/WITHDRAWAL_MANUAL_TEST.md`.
- Signup needs `consentVersion` `2026-10-05`.
- `.claude/launch.json` at the repo root has `smartmoney-admin` (5180), `smartmoney-backend` (7056, `https://localhost:7056`), `smartmoney-mobile` (8088). The preview tool reads `.claude/launch.json` from the session's primary folder. Port 5180 was once reported reserved by Windows; pick another if so.
- Backend runs at `https://localhost:7056`; Swagger at `/swagger`. In Development CORS allows any origin.
- Heredocs containing apostrophes break in this shell; write files with the file tool. Python is not installed; Node is.
- **`dart format` on whole directories reformats unrelated existing files.** Scope it to your own files and check `git status`.
- Flutter widget-test traps: match buttons with `find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>())` (`widgetWithText(ButtonStyleButton, ...)` matches the exact type); never `pumpAndSettle` while a request is held pending (fake time passes the client's 5-second timeout); an animation moves only on the frame after it starts, so after a tap that pops a route do `pump()` then `pump(600ms)`.
- LF to CRLF warnings from git are harmless.

## 9. State of the repo and the database

**Uncommitted (everything):** modified existing files in backend (wallet, cashback handlers, delete-account, DI, config, snapshot) and `admin/lib/features/shell/admin_shell.dart`; new backend files (withdrawal domain, application, infrastructure, controllers, migration, tests, two docs), the whole `admin/lib/features/withdrawals/` and `admin/test/features/`, and `docs/MILESTONES.md` plus this file. The owner has not decided how to commit; a sensible split is (1) backend feature with migration and tests, (2) admin withdrawals UI, (3) docs.

**Database (the owner's Supabase):** `AddWithdrawals` was applied on 11 Oct at the owner's request. A scripted end-to-end run (144 checks) left test data behind:
- User `wd-user-1011@example.com` (active). Wallet: 800 available, 0 held, 2200 withdrawn, 3000 earned. 15 withdrawals (7 Completed, 3 Failed, 3 Cancelled, 2 Rejected). Its password was only in a previous session's temporary folder, so register a new test user or reset it.
- A throwaway test admin `wd-admin-1011@example.com` was **deleted through the app (anonymised, cannot log in)**; its row still carries the SuperAdmin role on an anonymised, deleted account.
- Related click, conversions (`WDTEST-...`) and cashbacks remain.
- The owner's user secrets were never changed.

## 10. Related files
- `docs/CASHBACK_REVIEW_PLAN.md`: the cashback review rework (audit trail, approval gate, new page); its HANDOFF section is the entry point for that work.
- **Browser click-through, 11 Oct:** both apps were driven in the embedded browser pane (release builds). Mobile: create account with OTP, login, logout, home, explore and search, store page, Earn Cashback redirect (Myntra and the Flipkart offer), cashback tab and detail timeline, wallet, withdraw, history, cancel, profile. Admin: login, dashboard cards, cashback review with an approval, withdrawals list, detail, approve and mark paid, categories, stores, offers, cashback settings, affiliate networks with store mappings, users. No app defect found. Only four stores have affiliate mappings (BookMyShow, Flipkart, MakeMyTrip, Myntra); other stores open their plain website without tracking. A second round the same evening covered real SMTP (forgot-password and verify-email codes delivered to the owner), cashback Reject and Reverse in the admin, every Fake provider scenario from `backend/docs/WITHDRAWAL_MANUAL_TEST.md` section 8 including the attention badge and Acknowledge, the real rate limits, and token expiry with refresh. Record: `backend/tools/e2e/README.md`. Helpers: `tools/e2e/start-api-real.cmd` plus `overrides.cmd` (launch config `smartmoney-backend-real`).
- `backend/tools/e2e/run.mjs` and its `README.md`: the automated end-to-end run (sign-up, cashback via the Cuelinks simulator, admin approval, withdrawal, cancel, wallet invariants), 89 checks, first passed on 11 Oct. Each run adds `e2e-user-<run>@example.com` and `e2e-admin-<run>@example.com` (a SuperAdmin) plus their click, conversion, cashback and two withdrawals to the configured database; three runs were made on 11 Oct (`...153437`, `...153543`, `...153650`).
- `backend/docs/PAYOUT_PROVIDER_GUIDE.md`: how to connect a vendor.
- `backend/docs/WITHDRAWAL_MANUAL_TEST.md`: step-by-step manual API test, with a record of the first run.
- `docs/MILESTONES.md`: project status (M4 line is stale).
- `docs/legal/`: Terms Sections 8, 9, 14 describe the user-facing withdrawal rules.
- Claude memory notes under `C:\Users\royap\.claude\projects\D--Projects-Personal-SMARTMONEY\memory\` (working agreements, test-run gotchas, UI progress).
