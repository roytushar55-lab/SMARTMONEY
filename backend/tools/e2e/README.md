# End-to-end run: sign-up to paid withdrawal

`run.mjs` drives the whole money path through the real HTTP API and checks
every figure on the way:

```
sign up + verify (user and admin)
  -> restart so the admin is promoted
  -> admin cashback share for the Cuelinks network (sets 50% if unset)
  -> user taps Earn Cashback on a mapped store, redirect carries subid
  -> simulator postbacks: pending, pending again, validated, paid
       cashback = commission x share, one row only, parked for review
  -> admin confirms it: available balance, ledger entries
  -> user previews and requests a withdrawal (UPI, password)
  -> admin lists, opens (full UPI ID, no-store), approves, marks paid
  -> user sees Paid with the bank reference; bank details wiped
  -> a second request, cancelled by the user
  -> available + held + withdrawn = earned, ledger consistent
```

## Running it

From `backend/`:

```powershell
node tools/e2e/run.mjs
```

Needs Node 18 or newer and the .NET SDK. Nothing else: the script

- builds the API into its own temp folder and runs it on **port 7156**
  (`SM_E2E_PORT` to change), so a copy you have running on 7056 is never
  touched or locked;
- refuses to start if anything already answers on its port, so it can never
  talk to an instance with real email settings;
- overrides the risky settings **for that process only**: console OTP
  (`Email__Host` blank), SMTP password disabled, a throwaway super admin,
  a test webhook token, a flat payout fee of 10 so the fee maths is visible,
  and raised rate limits. Your user secrets are not read or changed;
- uses the **database the API is configured for**. It leaves behind two
  throwaway accounts (`e2e-user-<run>@example.com`,
  `e2e-admin-<run>@example.com`, the admin with the SuperAdmin role), one
  click, one conversion, one cashback and two withdrawals. Run it against a
  development database, or clean those up afterwards.

It needs the Cuelinks network and at least one store mapping in the
database (`docs/database/affiliate-seed.sql`); it stops with a clear message
if they are missing.

Output: one line per check, a summary, and exit code 0 only when everything
passed. The API's own console goes to `logs/e2e-api-<run>.log` (the OTPs are
read from there).

## Record of runs

| Date | Result | Notes |
|---|---|---|
| 11 Oct 2026 | 89 checks passed, 0 failed | Manual provider, 50% share, Myntra. Two earlier attempts failed only on the script's own expectations (register answers 201; an account holder's name may not contain digits; the admin list sends `destination: null`), fixed in the script. The app itself needed no change. |

## Manual round of 11 Oct 2026 (not scripted)

Run with `start-api-real.cmd` (real SMTP from user secrets) and these
`overrides.cmd` values: Fake provider, worker every 10 s, reconcile after
1 min, flat fee 10, 2-minute access tokens. All passed:

- **Real email:** forgot-password and resend-email-otp to `roytushar55@gmail.com`
  were delivered (the owner pasted both codes); reset-password and
  verify-email-otp accepted them, login then worked. That account's password
  was set by this run to the value in the test accounts table below; change it.
- **Cashback Reject and Reverse** from the admin screen: a validated cashback
  rejected from review; a confirmed cashback flagged by a `reversed` postback
  showed "Reverse" instead of "Reject" and reversed cleanly.
- **Fake provider:** Pending → Processing, completed by the worker's status
  check 64 s later; webhook Failed → Applied (money back), replay → Duplicate,
  Succeeded after Failed → NeedsAttention with no money moved, admin badge
  and dashboard card showed 1, Acknowledge cleared it; unknown provider 404,
  bad body 400, unknown reference Ignored; TemporaryFailure → 5 attempts
  ~10 s apart then flagged, reject refused mid-retry (409) and allowed after
  the flag; Reject → Failed at once with the raw text in `lastError`;
  Success → Completed on approve with a `FAKE-` reference.
- **Rate limits (real values):** withdrawals 429 after the 10th request in
  10 min, OTP resends after the 10th, logins after the 20th per minute with
  `Retry-After: 60`.
- **Token refresh:** expired access token → 401, refresh → 200, old refresh
  token reuse → 401; the admin app refreshed silently.
- Wallet invariant held throughout: available + held + withdrawn = earned.

One nit: after a provider rejection the detail shows `submissionAttempts: 0`
although one submission was made (the TemporaryFailure path counts them).

### Test accounts in the owner's database

| Email | Password | Role |
|---|---|---|
| `roytushar55@gmail.com` | password set during testing, deliberately not written here (change it) | user, verified |
| `ui-user-20261011@example.com` | `Ui@Test12345` | user |
| `e2e-user-20261011153650@example.com` | `E2e@Pass12345` | user |
| `e2e-admin-20261011153650@example.com` | `E2e@Admin12345` | SuperAdmin |
