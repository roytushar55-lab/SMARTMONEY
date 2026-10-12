# Withdrawals: manual end-to-end test

Run this once on your own machine before the feature is committed or
deployed. It uses the **Manual** provider (the real day-one setup: you act as
the admin who pays by bank app and records the reference), then optionally the
**Fake** provider to exercise the automatic path.

The mobile and admin apps have no withdrawal screens yet, so everything below
is done through **Swagger** (`https://localhost:7056/swagger`) and SQL.

Tick each box as you go. A line starting **Expect** is the pass condition; if
it differs, stop and note what you saw.

---

## 0. Before you start

- [ ] **Use a development database**, or take a backup first. The migration
  adds columns and a table; it does not delete anything, but it is a schema change.
- [ ] Review the SQL if you want to (nothing is applied by this command):

  ```powershell
  cd D:\Projects\Personal\SMARTMONEY\backend
  dotnet ef migrations script 20261005071704_SecurityHardening AddWithdrawals --project src/SmartMoney.Infrastructure --startup-project src/SmartMoney.Api
  ```

- [ ] Apply the migration:

  ```powershell
  dotnet ef database update --project src/SmartMoney.Infrastructure --startup-project src/SmartMoney.Api
  ```

  **Expect:** `Done.` and these changes in the database: table `Withdrawals`;
  new columns `Wallets.HeldBalance`, `WalletTransactions.HeldBalanceAfter`,
  `WalletTransactions.WithdrawalId`.

- [ ] Set the test settings **as environment variables in the shell that
  starts the API**, not as user secrets. Environment variables override user
  secrets for that run only, so your real configuration is never touched.

  ```powershell
  # IMPORTANT if Email:Host is configured in your secrets: a blank host makes
  # the app print OTP codes to the console instead of sending real emails.
  # Without this, every test signup sends a real email through your SMTP account.
  $env:Email__Host = " "
  $env:Email__Password = "disabled-for-test"   # fail-safe: SMTP login would fail rather than send

  $env:Payouts__FlatFee = "10"                          # makes the fee maths visible
  $env:RateLimiting__WithdrawalRequestsPerTenMinutes = "200"
  $env:Seed__SuperAdminEmail = "wd-admin-test@example.com"   # a throwaway admin, see section 1
  ```

  The rate-limit setting matters: the real limit is 10 withdrawal requests
  per 10 minutes per IP, and sections 3 to 5 send more than that. You test
  the real limit separately in section 5.

  With a flat fee of 10: total fee = 10 + 18% tax = **11.80**, the user pays
  half = **5.90**, so a 500 withdrawal pays out **494.10**.

- [ ] Start the API **from that same shell**:

  ```powershell
  dotnet run --project src/SmartMoney.Api --launch-profile https
  ```

  **Expect:** it starts with no exception, and the console shows
  `Withdrawal worker idle: payout provider 'Manual' is paid by hand.`
  Open `https://localhost:7056/swagger`.

> Swagger auth: after you log in, click **Authorize** and paste the raw
> `accessToken` (no `Bearer ` prefix). Switch tokens when you switch between
> the user and the admin.

---

## 1. Two accounts: a user and an admin

You need a normal user (the one who withdraws) and an admin (who approves and
pays). Use two different email addresses.

For each, call `POST /api/identity/register`:

```json
{
  "fullName": "Test User",
  "email": "user-test@example.com",
  "phoneNumber": "9876543210",
  "password": "Test@12345",
  "ageConfirmed": true,
  "termsAccepted": true,
  "consentVersion": "2026-10-05"
}
```

(Passwords need upper and lower case, a digit and a symbol, 8+ characters.
Use a second phone number for the admin.)

- [ ] Register the **user** and the **admin** (the admin email must equal
  `Seed:SuperAdminEmail`).
- [ ] In the API console (Development prints the codes), find each OTP, then
  `POST /api/identity/verify-email-otp` `{ "email": "...", "otp": "..." }`.
- [ ] **Restart the API once.** The super admin promotion runs at startup and
  only after the admin has registered.
- [ ] `POST /api/identity/login` for both. Save both `accessToken`s and the
  user's `userId`. **Log the admin in after the restart**, so the token
  carries the admin role.
- [ ] **Expect:** with the admin token `GET /api/admin/withdrawals` returns
  `200` and an empty list; with the user token it returns `403`; with no token `401`.

---

## 2. Put money in the user's wallet

Withdrawals need available balance. You want about **₹1,500 or more**, so you
can run several scenarios. Pick one path.

### Path A: through the real cashback pipeline (recommended)

This also tests that the ledger and held balances still behave with real data.

1. As the user, `GET /api/stores`, then `POST /api/affiliate/clicks` with a
   store that has cashback (for example Myntra): `{ "storeId": "<store guid>", "offerId": null }`.
   Note `redirectToken`.
2. Request `GET /r/<redirectToken>` without following the redirect (in Swagger
   it shows as a 3xx). The `Location` header is the merchant URL; copy its
   `subid=` value. (Or read `TrackingReference` from the newest
   `AffiliateClicks` row.)
3. As the **admin**, post the conversion yourself with
   `POST /api/affiliate/conversions`. This needs no webhook token or
   simulator. Send it twice with the same `networkTransactionId`, first with
   `networkStatus: "pending"`, then `"validated"`:

   ```json
   {
     "networkCode": "CUELINKS",
     "networkTransactionId": "WDTEST-0001",
     "trackingReference": "<subid>",
     "networkStatus": "validated",
     "orderAmount": 30000,
     "commissionAmount": 6000,
     "currency": "INR",
     "rawPayload": "{}"
   }
   ```

   The cashback is `commissionAmount × UserSharePercent` from your cashback
   settings (with a 50% share, 6000 gives 3000). A `validated` status parks it
   in review; it does not credit the wallet by itself.
4. As the admin, `GET /api/admin/cashbacks?status=AwaitingAdminReview`, copy
   the cashback `id`, and `POST /api/admin/cashbacks/{id}/approve`. (The admin
   app's Cashbacks screen does the same.)
5. **Expect:** as the user, `GET /api/wallet` shows `availableBalance` of
   about 1,500 or more. Repeat 1-4 if you need more.

(`tools/affiliate-simulator/Send-Postback.ps1` also works, but needs your
`Webhooks:CuelinksToken`, `-BaseUrl https://localhost:7056`, and a larger
commission than its default of 250.)

### Path B: shortcut with SQL (fast, but skips the ledger)

Use this if you just want to test withdrawals. It credits the wallet directly,
so the wallet ledger has no matching entry for the opening balance.

```sql
-- If the user already has a wallet:
update "Wallets" set "AvailableBalance" = 2000, "TotalEarned" = 2000, "UpdatedAt" = now()
where "UserId" = '<userId>';

-- If not:
insert into "Wallets" ("Id","UserId","AvailableBalance","PendingBalance","HeldBalance","TotalEarned","TotalWithdrawn","CreatedAt")
values (gen_random_uuid(), '<userId>', 2000, 0, 0, 2000, 0, now());
```

**Expect:** `GET /api/wallet` shows `availableBalance: 2000`, `heldBalance: 0`.

---

## 3. The main flow: request, approve, pay (UPI)

All user steps use the **user** token; admin steps use the **admin** token.
Let `A` be the available balance before you start.

1. **Preview.** `GET /api/withdrawals/preview?amount=500`.
   **Expect:** `feeTotal 11.80`, `userFee 5.90`, `netAmount 494.10`,
   `canWithdraw true`, `userFeeSharePercent 50`.
2. **Preview, problems come back as messages, not errors** (still `200`).
   - `amount=100` → `canWithdraw false`, message about the ₹250 minimum.
   - `amount=60000` → `canWithdraw false`, message about the ₹50000 maximum.
   - An amount between 250 and 50000 that is more than your balance (for
     example `40000`) → `canWithdraw false`, "available balance is lower".
3. **Request.** `POST /api/withdrawals`:

   ```json
   {
     "amount": 500,
     "method": "Upi",
     "beneficiaryName": "Test User",
     "upiId": "testuser@okhdfc",
     "password": "Test@12345"
   }
   ```

   **Expect:** `201`, `status: "Requested"`, `amount 500`, `userFee 5.90`,
   `netAmount 494.10`, `destination: "te****@okhdfc"` (never the full ID),
   `canCancel: true`. Save the `id` and `reference` (looks like `WD20261011K7QM2XA9PD`).
4. **Money is held.** `GET /api/wallet`.
   **Expect:** `availableBalance = A − 500`, `heldBalance = 500`.
5. **Ledger.** `GET /api/wallet/transactions`.
   **Expect:** a `WithdrawalRequested` entry of 500.
6. **One open withdrawal at a time.** Send the same `POST /api/withdrawals` again.
   **Expect:** `409` "You already have a withdrawal in progress…". The wallet is unchanged.
7. **Admin sees it.** `GET /api/admin/withdrawals?status=Requested`.
   **Expect:** one item, with the user's name and email, and `destinationMasked`
   only (no full details in the list).
8. **Admin detail.** `GET /api/admin/withdrawals/{id}`.
   **Expect:** `destination` with `upiId: "testuser@okhdfc"` and
   `beneficiaryName`, and the response header `Cache-Control: no-store`.
   This is what you would pay: **494.10** to that UPI ID. (In a real run you
   pay it now from your bank app.)
9. **Approve.** `POST /api/admin/withdrawals/{id}/approve`.
   **Expect:** `status: "Approved"`. Nothing else happens (the manual
   provider sends nothing); the user's balances are unchanged.
10. **User can no longer cancel.** `POST /api/withdrawals/{id}/cancel`.
    **Expect:** `409` "…can only be cancelled before it is approved".
11. **Record the payment.** `POST /api/admin/withdrawals/{id}/mark-paid`:

    ```json
    { "transactionReference": "UTR123456789012" }
    ```

    **Expect:** `status: "Completed"`, `heldBalance: 0`.
12. **User sees the result.** `GET /api/withdrawals/{id}`.
    **Expect:** `status: "Completed"`, `transactionReference: "UTR123456789012"`,
    `settledAt` set. `GET /api/wallet`: `heldBalance 0`, `totalWithdrawn 500`,
    `availableBalance = A − 500`.
13. **Ledger.** **Expect:** a `WithdrawalCompleted` entry of 500 with `heldBalanceAfter 0`.
14. **Bank details are gone.** Admin `GET /api/admin/withdrawals/{id}` again.
    **Expect:** `destination` is `null` now that it has settled.
15. **Double pay is refused.** Repeat the `mark-paid` call.
    **Expect:** `409`; the balances do not change again.

---

## 4. The other outcomes

Each starts with a fresh request (the previous one must be finished first).
Use `"amount": 250` to keep the numbers small.

### 4a. User cancels

- [ ] Request, then `POST /api/withdrawals/{id}/cancel`.
  **Expect:** `status: "Cancelled"`, `availableBalance` back to what it was,
  `heldBalance 0`; ledger gets a `WithdrawalReleased` entry. Cancel again →
  `409`. Other users' ids → `404`.

### 4b. Admin rejects

- [ ] Request, then admin `POST /api/admin/withdrawals/{id}/reject` with
  `{ "reason": "" }`. **Expect:** `400` (a reason is required).
- [ ] Reject with `{ "reason": "Name does not match the account." }`.
  **Expect:** `Rejected`, money released. As the user,
  `GET /api/withdrawals/{id}` shows `failureReason` with that text.

### 4c. Approved, then the payment fails

- [ ] Request, approve, then `POST /api/admin/withdrawals/{id}/mark-failed`
  with `{ "reason": "The bank returned the payment." }`.
  **Expect:** `Failed`, money back in available, the user sees the reason.
- [ ] A new request, **not approved**, then `mark-failed`.
  **Expect:** `409` (use reject for something nobody approved). Reject it afterwards to tidy up.

### 4d. Approve and pay in one go

- [ ] Request, then straight to `mark-paid` without approving first.
  **Expect:** `Completed` (it approves and completes in one call).

### 4e. Bank transfer

- [ ] Request with:

  ```json
  {
    "amount": 250,
    "method": "BankTransfer",
    "beneficiaryName": "Test User",
    "bankAccountNumber": "123456789012",
    "ifscCode": "hdfc0001234",
    "password": "Test@12345"
  }
  ```

  **Expect:** `destination: "HDFC0001234 ****9012"`. Admin detail shows the full
  account number and the upper-cased IFSC while open. Finish it with `mark-paid`.

---

## 5. Things that must be refused

Send each and check the status. None of them should change any balance.

| Request | Expect |
|---|---|
| Wrong `password` | `400` "Incorrect password." |
| `amount` 249 or 0 or negative | `400`, minimum message |
| `amount` 300.555 | `400`, "at most two decimal places" |
| `amount` greater than available | `409` "available balance is lower" |
| `upiId` `"nobank"` or `"a@b"` | `400` "valid UPI ID" |
| `ifscCode` `"HDFC1001234"` (5th char not 0) | `400` "valid IFSC" |
| `bankAccountNumber` `"12345"` | `400` "9 to 18 digits" |
| `method` `"Cash"` | `400` |
| `beneficiaryName` `""` or `"1234"` | `400` |
| Any user endpoint with no token | `401` |
| Admin endpoint with the user's token | `403` |
| Unknown withdrawal id | `404` |

- [ ] **Rate limit.** Set `RateLimiting:WithdrawalRequestsPerTenMinutes` to `3`
  (user-secrets) and restart. Send four `POST /api/withdrawals` (they can be
  invalid, for example a wrong password; the limit counts requests, not
  successes). **Expect:** `429` "Too many requests" on the 4th, with a
  `Retry-After` header. Set it back to `200` and restart.

---

## 6. The held money blocks account deletion

- [ ] Make a Requested withdrawal, then as that user `POST /api/profile/delete-account`
  with `{ "password": "Test@12345" }`.
  **Expect:** `409` "A withdrawal is still in progress…". The account is unchanged.
  Cancel the withdrawal afterwards.

---

## 7. Check the database

Run these after the scenarios.

```sql
-- Every withdrawal. has_details must be false once it is final.
select "Reference","Status","Amount","UserFee","NetAmount","DestinationMasked",
       "DestinationProtected" is not null as has_details,
       "ProviderReference","FailureReason","NeedsAttention","SubmissionAttempts"
from "Withdrawals" order by "CreatedAt" desc;

-- The ledger for the user, in order.
select "Type","Amount","AvailableBalanceAfter","PendingBalanceAfter","HeldBalanceAfter","Description"
from "WalletTransactions" where "UserId" = '<userId>' order by "CreatedAt";

-- The wallet adds up (only meaningful if you funded it with Path A).
select "AvailableBalance" + "HeldBalance" + "TotalWithdrawn" as accounted, "TotalEarned"
from "Wallets" where "UserId" = '<userId>';
```

- [ ] **Expect:** `DestinationProtected` is non-null only for open
  withdrawals, and its value is unreadable text, not the UPI or account number.
- [ ] **Expect:** every Requested has a later Completed or Released entry
  (except any still open); `HeldBalanceAfter` is never negative.
- [ ] **Expect (Path A):** `accounted` equals `TotalEarned`.

---

## 8. Optional: the automatic path with the Fake provider

This tests submission, the background worker, status checks, retries and the
webhook, with no real vendor. It only works in Development.

Set these in the shell, then **restart the API from it** (and settle every open withdrawal first). Change `Payouts__Fake__Behavior` and restart for each scenario below. For 8b to 8h set `$env:Payouts__RequireAdminApproval = "false"` so the request itself sends; for 8a keep it on.

```powershell
$env:Payouts__Provider = "Fake"
$env:Payouts__WorkerIntervalSeconds = "10"
$env:Payouts__ReconcileAfterMinutes = "1"
$env:Payouts__Fake__Behavior = "Success"   # or Pending, TemporaryFailure, Reject
```

**Expect** at startup: `Withdrawal worker started for provider 'Fake', every 10s.`

### 8a. Immediate success

- [ ] Request, then admin **approve**.
  **Expect:** the approve response is already `status: "Completed"`;
  `providerReference` starts `FAKE-`; the user's `totalWithdrawn` rose and
  `heldBalance` is 0.

### 8b. Accepted, then confirmed later

Set `Payouts:Fake:Behavior` to `Pending`, restart.

- [ ] Request, approve. **Expect:** `Processing`, held balance still 500.
- [ ] Wait about 1 to 2 minutes (one status-check window). **Expect:** the
  worker's status check completes it: `Completed`, money withdrawn.

### 8c. Failure through the webhook

Behavior `Pending`. Request and approve (`Processing`), then call
`POST /api/webhooks/payouts/Fake` (no token needed) with:

```json
{ "reference": "<the WD... reference>", "state": "Failed" }
```

- [ ] **Expect:** `200` `outcome: "Applied"`; the withdrawal is `Failed`
  with a plain reason; the money is back in available.
- [ ] Send the same body again. **Expect:** `200` `outcome: "Duplicate"`; no change.
- [ ] Send `{ "reference": "<same>", "state": "Succeeded" }`.
  **Expect:** `200` `outcome: "NeedsAttention"`; the withdrawal stays `Failed`,
  `needsAttention: true` in the admin list (`?needsAttention=true`), and **no
  money moves**. Then `POST /api/admin/withdrawals/{id}/acknowledge` clears it.
- [ ] `POST /api/webhooks/payouts/SomeoneElse` → `404`. Body `not json` → `400`.
  An unknown reference → `200` `outcome: "Ignored"`.

### 8d. Provider keeps failing

Behavior `TemporaryFailure`, restart. Request, approve.

- [ ] **Expect:** `Approved` with `submissionAttempts` rising each ~10 seconds
  (admin detail shows `lastError`), until 5, then `needsAttention: true` and no more attempts.
- [ ] Admin `reject` now works (it needs attention). Before the first attempt,
  and with the Manual provider, reject always works. In between it is refused
  with `409` "already been sent to the payment provider". This is the guard
  against paying and refunding the same money.

### 8e. Provider says no

Behavior `Reject`, restart. Request, approve.

- [ ] **Expect:** `Failed` immediately; the user sees a plain message
  ("The payout could not be completed. The money is back in your wallet.");
  the admin detail shows the provider's raw text in `lastError`.

### Back to normal

- [ ] Close the shell (or clear `$env:Payouts__Provider`) so `Manual` is used again, and
  restart. Settle anything still open first.

---

## 9. Sign-off

You can treat the feature as working end to end when:

- [ ] Sections 3, 4 and 5 pass with no unexpected status code.
- [ ] Section 7 shows consistent withdrawals, ledger and wallet figures.
- [ ] Held money never went negative and was always either spent or returned.
- [ ] (Optional) Section 8 passes.

If anything fails, note the request, the response, and the matching rows from
the section 7 queries.

## Not covered here

- Production startup requirements (`DataProtection:KeysPath` plus a
  certificate or DPAPI): set them for the real deployment.
- A real vendor: see `PAYOUT_PROVIDER_GUIDE.md`.
- Mobile and admin app screens: they do not exist yet.

---

## Record of the first run (11 October 2026)

Run against the configured database after applying the `AddWithdrawals`
migration, driven through the HTTP API with throwaway test accounts. All of
sections 1 to 6 and 8 (8a to 8h) passed, 144 checks in all, with the rate-limit
check at a limit of 3. The SQL checks in section 7 were not run; the same
facts were checked through the API (settled withdrawals show no bank details,
and the wallet adds up: available + held + withdrawn = earned).

Two things found while running it, both now fixed in this document: the
signup consent version must be `2026-10-05`, and a configured `Email:Host`
sends real emails on signup unless blanked (see section 0).
