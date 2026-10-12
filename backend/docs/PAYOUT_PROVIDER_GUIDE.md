# Payout Provider Guide

How to connect a payout vendor (the service that actually sends money to a
user's bank account or UPI ID) to SmartMoney.

**The short version:** write one adapter class, add one line to a list, set
two config values, write a test. Nothing else changes. Wallet holds, fees,
approval, the ledger, admin screens, the webhook route and the retry worker
are already built and do not know which vendor is behind them.

Until a vendor is connected, the **Manual** provider is active: an admin pays
the user by bank or UPI app, then records the bank reference in the admin API.

---

## 1. What already exists (do not rebuild it)

| Concern | Where |
|---|---|
| Money rules: hold on request, release on failure, spend on success | `Domain/Entities/Wallet.cs`, `Application/Features/Withdrawals/WithdrawalSettlement.cs` |
| Limits and fee maths | `Application/Common/PayoutPolicy.cs`, settings in `Payouts` config |
| Request, cancel, preview, list (user) | `WithdrawalsController` |
| Approve, reject, mark paid, mark failed, acknowledge (admin) | `AdminWithdrawalsController` |
| Sending approved payouts, retries, asking the provider for status | `Application/Features/Withdrawals/WithdrawalProcessor.cs`, `Infrastructure/Payouts/WithdrawalWorker.cs` |
| Webhook route and idempotent handling | `PayoutWebhooksController`, `ProcessPayoutWebhookCommandHandler` |
| Encrypted bank details, wiped when a withdrawal finishes | `DataProtectionPayoutDestinationProtector` |
| Choosing the provider from config, startup checks | `Infrastructure/Payouts/PayoutProviders.cs`, `PayoutStartupValidator.cs` |

The only vendor-specific work is translating between SmartMoney's neutral
types and the vendor's API.

## 2. The contract: `IPayoutProvider`

File: `Application/Abstractions/Payouts/IPayoutProvider.cs`. Types are in
`PayoutContracts.cs`.

```csharp
string Name { get; }                   // config + webhook URL id, e.g. "Acme"
bool SupportsAutomaticPayout { get; }  // true: the app and worker call you

Task<PayoutSubmissionResult> SubmitAsync(PayoutInstruction, CancellationToken);
Task<PayoutStatusResult>     GetStatusAsync(string reference, string? providerReference, CancellationToken);
Task<PayoutWebhookEvent?>    ParseWebhookAsync(PayoutWebhookRequest, CancellationToken);
```

### SubmitAsync: send one payout

`PayoutInstruction` carries `Reference`, `Amount` (the **net** amount to send,
in rupees, after the user's share of the fee), `Currency` ("INR"), the
`Destination` and a `Narration`.

- **`Reference` is the idempotency key.** It is unique per withdrawal and is
  re-sent unchanged on every retry. Pass it to the vendor as its own
  idempotency key or client reference, so that submitting twice can never pay
  twice. This is the single most important rule in this guide. If the vendor
  has no idempotency support, do a status lookup by reference before sending.
- Convert rupees to whatever the vendor wants (paise, strings) inside your
  adapter. Do not change the shared types.
- **Return a result for expected outcomes, do not throw:**

| Return | Meaning | What SmartMoney does |
|---|---|---|
| `Accepted(providerRef)` | Vendor took it; result comes later | Status becomes Processing; waits for webhook or status check |
| `Completed(providerRef, fee)` | Vendor already finished (instant rails) | Money is settled immediately |
| `Rejected(message)` | Permanent refusal: bad account, blocked, over a limit | Withdrawal fails, money returns to the user. **`message` is stored for admins only**; the user sees a plain generic reason |
| `TemporaryFailure(message)` | Timeout, vendor outage, 5xx, rate limit | Retried by the worker up to `Payouts:MaxSubmissionAttempts`, then flagged for an admin |

- An exception is treated as a temporary failure. Prefer returning
  `TemporaryFailure` with a short message so the log is readable.
- Decide carefully between `Rejected` and `TemporaryFailure`. Calling a
  transient error `Rejected` refunds the user while the vendor may still pay.
  When in doubt (an ambiguous timeout after the request was sent), return
  `TemporaryFailure`: the retry is safe because of the idempotency key.
- Never log the destination (account number, UPI ID).

### GetStatusAsync: where does it stand?

Used when no webhook arrived (default: after 15 minutes in Processing).
Return `PayoutStatusResult` with `State` = `Pending`, `Succeeded`, `Failed`
or `Unknown`. Use `Unknown` only when the vendor genuinely has no record of
the reference: SmartMoney flags that withdrawal for an admin and does not
move money. Map the vendor's intermediate states (queued, processing,
pending approval) to `Pending`. Include `ActualFee` when the vendor reports
the real fee.

### ParseWebhookAsync: verify, then decode

The webhook route is `POST /api/webhooks/payouts/{provider}` where
`{provider}` equals your `Name` (case-insensitive). You receive the raw body
and all headers.

- **Verify the vendor's signature here**, using the secret from
  configuration, with a constant-time comparison
  (`CryptographicOperations.FixedTimeEquals`). Return `null` if it fails.
  Nothing is trusted until you return an event.
- **Sign over `request.RawBody`, the exact bytes received**, not over
  `request.Body`. `Body` is that data decoded to text, and decoding can drop a
  byte-order mark or replace invalid bytes, so an HMAC computed over `Body`
  can fail on a genuine callback. Use `Body` (or parse `RawBody` as JSON) only
  after the signature has been verified. Bodies over 64 KB are refused before
  they reach you (413).
- Return `null` (never throw) for a missing signature, a bad signature or a
  body you do not understand. The caller answers 400.
- If the vendor signs a timestamp, reject stale ones to blunt replays.
- Return a `PayoutWebhookEvent` with `Reference` (ours) and/or
  `ProviderReference`, the `State`, an optional message and fee. Webhooks may
  repeat or arrive out of order; the settlement logic handles both, you only
  decode.

## 3. Step by step

1. **Create the adapter** in `Infrastructure/Payouts/`, for example
   `AcmePayoutProvider.cs`, implementing `IPayoutProvider`. Skeleton:

   ```csharp
   public sealed class AcmePayoutProvider : IPayoutProvider
   {
       private readonly HttpClient _http;
       private readonly AcmePayoutOptions _options;

       public AcmePayoutProvider(HttpClient http, IOptions<AcmePayoutOptions> options)
       {
           _http = http;
           _options = options.Value;
       }

       public string Name => "Acme";
       public bool SupportsAutomaticPayout => true;

       public async Task<PayoutSubmissionResult> SubmitAsync(
           PayoutInstruction instruction, CancellationToken ct)
       {
           // 1. Build the vendor request. Send instruction.Reference as the
           //    vendor's idempotency / client reference.
           // 2. Call the vendor.
           // 3. Map the answer: Accepted / Completed / Rejected / TemporaryFailure.
       }

       // GetStatusAsync, ParseWebhookAsync: see section 2.
   }
   ```

   Put the vendor's base URL, key id and secrets in an options class bound
   from configuration. Follow `Affiliate/CuelinksOptions.cs` and
   `CuelinksAffiliateNetworkClient.cs` for HTTP client style.

2. **Register it**: add one entry to `Catalog` in
   `Infrastructure/Payouts/PayoutProviders.cs` (a commented example is in
   the file):

   ```csharp
   ["Acme"] = new(
       sp => ActivatorUtilities.CreateInstance<AcmePayoutProvider>(sp),
       DevelopmentOnly: false),
   ```

   If the adapter needs an `HttpClient` or options, also register those in
   `DependencyInjection.cs` (for example `services.AddHttpClient<AcmePayoutProvider>()`
   and `services.Configure<AcmePayoutOptions>(...)`), and construct it from
   the factory with `sp.GetRequiredService<AcmePayoutProvider>()` instead.

3. **Configure it** (secrets in User Secrets or the host's environment, never
   in `appsettings.json`):

   ```json
   "Payouts": {
     "Provider": "Acme",
     "FlatFee": 5,
     "PercentFee": 0,
     "FeeTaxPercent": 18,
     "MaximumAmount": 50000
   },
   "Acme": { "KeyId": "...", "KeySecret": "...", "WebhookSecret": "..." }
   ```

   Set `FlatFee`, `PercentFee` and `FeeTaxPercent` to the vendor's real price
   list. `UserFeeSharePercent` is 50 per the Terms of Service. The defaults
   charge nothing, so the app never invents a fee. The user sees the fee
   before confirming (`GET /api/withdrawals/preview`), and the amount sent to
   the vendor is the net amount.

4. **Register the webhook** in the vendor's dashboard:
   `https://<your-api-host>/api/webhooks/payouts/Acme`.

5. **Write tests** (see section 5).

6. **Check the deployment**, section 6.

## 4. How a payout flows (for debugging)

```
user requests  -> money held (Available -> Held), status Requested
admin approves -> status Approved                (or automatic if approval is off)
processor      -> SubmitAsync
    Accepted         -> Processing ... webhook / GetStatusAsync -> Completed or Failed
    Completed        -> Completed
    Rejected         -> Failed (money back)
    TemporaryFailure -> stays Approved, worker retries; after MaxSubmissionAttempts -> NeedsAttention
Completed: Held -> TotalWithdrawn, bank details wiped
Failed / Rejected / Cancelled: Held -> Available, bank details wiped
```

Safety nets, all automatic:

- A provider report that contradicts our records is **never applied**. It
  flags the withdrawal `NeedsAttention` instead (for example "success" after
  we already refunded the user). Paying twice is worse than asking a human.
- Admins can only settle an automatic-provider withdrawal by hand once it
  needs attention or its retries are used up, so a human and the vendor cannot
  both pay.
- The worker runs only when `SupportsAutomaticPayout` is true.
- **The attempt is saved before your `SubmitAsync` is called.** That save
  changes the withdrawal's row, so an admin action that loaded it earlier
  loses the race instead of overlapping with your payout. If the save loses,
  `SubmitAsync` is never called.
- **After that point an admin cannot reject the withdrawal** (which would
  refund the user) unless it needs attention or its retries are used up. The
  vendor may still pay a submission that timed out, and a refund on top of it
  would pay the user twice. Mark paid and mark failed follow the same rule.
  Rejecting before any attempt, or with the manual provider, is always allowed.

## 5. Testing an adapter

- **Unit tests** with a fake `HttpMessageHandler` or a mocked client. Cover:
  every `SubmitAsync` outcome (accepted, completed, rejected, timeout, 5xx),
  idempotency (same `Reference` sent on retry), each `GetStatusAsync` state,
  and `ParseWebhookAsync` with a valid signature, a wrong signature, a missing
  header, malformed JSON and a stale timestamp. Existing examples:
  `tests/SmartMoney.Application.Tests/Withdrawals/PayoutInfrastructureTests.cs`
  (providers) and `ProcessPayoutWebhookHandlerTests.cs` (the handler).
- **Local end-to-end** before the vendor's sandbox: run in Development with
  `"Payouts": { "Provider": "Fake", "ReconcileAfterMinutes": 1, "WorkerIntervalSeconds": 10, "Fake": { "Behavior": "Pending" } }`.
  Submit leaves the withdrawal Processing, and the worker completes it on its
  first status check after `ReconcileAfterMinutes`. Post to `/api/webhooks/payouts/Fake` with
  `{"reference":"WD...","state":"Failed"}` to see the failure path. The Fake
  provider is refused outside Development.
- **Vendor sandbox:** run one successful payout, one rejected payout (an
  invalid account), one timeout if the sandbox can simulate it, and replay a
  webhook twice to confirm the second is a harmless duplicate.

## 6. Before going live

- [ ] `Payouts:Provider` names the adapter; unknown names stop the app at startup.
- [ ] Fee settings match the vendor's price list; `MaximumAmount` is a real business decision.
- [ ] `DataProtection:KeysPath` points at a **persistent** folder (not part of the deploy artifact). Bank details are encrypted with these keys; if they are lost, open withdrawals cannot be paid or read. Back the folder up. The app refuses to start outside Development without it.
- [ ] The key files are **encrypted at rest**. Otherwise they are plain XML, and anyone who can read the folder or a backup of it, together with a database dump, can decrypt every open withdrawal's bank details. Set `DataProtection:CertificatePath` (a `.pfx` file) and `DataProtection:CertificatePassword` (from the secret store), or `DataProtection:UseDpapi=true` on a Windows host. Keep a copy of the certificate with the keys backup: without it the key files cannot be read. Only the configured certificate is used to read the keys, so **replacing it makes the existing key files unreadable**: settle or reject every open withdrawal first, or extend `DependencyInjection.cs` with `UnprotectKeysWithAnyCertificate(oldCertificate)` before swapping. The app refuses to start outside Development with none of these; `DataProtection:AllowUnencryptedKeys=true` is an explicit "I accept plain-text keys" override and should not be used on a shared host.
- [ ] Vendor secrets and webhook secret are in the host's secret store, not in git.
- [ ] Webhook URL registered with the vendor, and reachable over HTTPS.
- [ ] Run **one real small payout** and reconcile it with the vendor's statement.
- [ ] Update the Privacy Policy and Terms of Service. They name Cashfree as the payout processor and must name the actual vendor. Bump the stored consent version if the wording changes materially.
- [ ] Decide `RequireAdminApproval`. It defaults to true; switching it off pays users with no human check.
- [ ] Admins know to watch `GET /api/admin/withdrawals?needsAttention=true`.

## 7. Changing provider later

Add the new adapter, register it, and change `Payouts:Provider`. **Settle
every withdrawal that is Approved or Processing before you switch.**

- **From Manual to a vendor (the first switch):** an Approved withdrawal under
  the manual provider means an admin has agreed to pay it, and may already
  have paid it from a bank app without recording it yet. The new provider's
  worker submits every Approved withdrawal it finds, so any such withdrawal
  would be paid a second time. Before switching, open
  `GET /api/admin/withdrawals?status=Approved`, and for each one either record
  it as paid (`mark-paid`, with the bank reference) or, if it has not been
  paid, reject it or leave it for the vendor to pay knowingly. Requested
  withdrawals are fine to leave: they have no payment history, and approving
  them later sends them through the new provider.
- **From one vendor to another:** Approved and Processing withdrawals keep
  their old `ProviderName`, but status checks and webhooks go only to the
  active provider, so the old vendor's in-flight payouts would never be
  resolved. Let them finish (or settle them by hand once they are flagged)
  before switching.
- Do the switch at a quiet time, and watch
  `GET /api/admin/withdrawals?needsAttention=true` afterwards.
