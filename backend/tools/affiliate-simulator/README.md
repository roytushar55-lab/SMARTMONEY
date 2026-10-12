# Affiliate Simulator

Plays the role of Cuelinks so the full tracking pipeline can be demonstrated
without provider credentials:

```
app login -> Earn Cashback -> POST /api/affiliate/clicks -> GET /r/{token}
    -> merchant URL carrying ?subid={TrackingReference}   (mock network client)
simulator -> POST /api/webhooks/cuelinks?token=...        (this tool)
    -> AffiliateConversion upsert (idempotent)
    -> Cashback created/transitioned (never PaidOut from a network status)
```

## Setup

1. Backend running locally with the `Webhooks:CuelinksToken` user secret set.
2. Export the token for the script:

```powershell
$env:SM_WEBHOOK_TOKEN = "<Webhooks:CuelinksToken value>"
```

3. Tap **Earn Cashback** in the app (logged in, store with an active affiliate
   mapping). Grab the `subid` query value from the merchant URL you land on,
   or read `TrackingReference` from the newest `AffiliateClicks` row.

## Scenarios

```powershell
.\Send-Postback.ps1 -SubId <ref> -Scenario happy-path      # pending -> validated -> paid
.\Send-Postback.ps1 -SubId <ref> -Scenario rejected        # pending -> rejected
.\Send-Postback.ps1 -SubId <ref> -Scenario reversal        # validated then reversed
.\Send-Postback.ps1 -SubId <ref> -Scenario duplicate       # replays; single conversion+cashback
.\Send-Postback.ps1 -SubId <ref> -Scenario unattributable  # unknown sub_id kept for review
```

Expected after `happy-path`: one `AffiliateConversions` row (NetworkStatus
`paid`), one `Cashbacks` row with Status **Confirmed** (2) — never PaidOut —
and `CashbackAmount = commission x UserSharePercent` from `CashbackSettings`.

The payload field names mirror the publicly documented Cuelinks Transaction
Update conventions; verify against a live account before pointing real
postbacks here.

## Web page (local tool)

A browser front end for the same postbacks, in `ui/`. It runs on your machine
only and keeps the webhook token on its server side, never in the page.

```
set SM_WEBHOOK_TOKEN=<Webhooks:CuelinksToken value>      (cmd; PowerShell: $env:SM_WEBHOOK_TOKEN = "...")
tools\affiliate-simulator\ui\start.cmd                    (from backend\; or: node tools/affiliate-simulator/ui/server.mjs)
```

Open http://localhost:5290.

1. **Create a tracked click:** enter a test user's email and password and choose a
   store. The tool signs in, creates the click and follows the redirect inside the
   API (it never leaves it), then fills in the `subid` for you. The password is
   used once, then cleared; it is not stored or logged. Only stores with an active
   affiliate mapping give a subid; others explain why not.
2. **The sale:** the subid (or paste one from any click), the commission and sale
   amount, and an expected-cashback hint (commission times the share percent you
   type; a store override changes the real figure). Then run a scenario (the same
   five as the PowerShell script) or send a single status. Leave the transaction id
blank for a new sale each run; press "Use last" to move the previous sale along.
Every request and answer is logged with its outcome.

Settings: `SM_SIM_TARGET` (default `https://localhost:7056`), `SM_SIM_PORT`
(default `5290`). It listens on 127.0.0.1 only and refuses a non-local target
unless `SM_SIM_ALLOW_REMOTE=1`. Tests: `node --test tools/affiliate-simulator/ui/simulator.test.mjs`.
