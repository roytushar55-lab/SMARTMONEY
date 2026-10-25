# Deployment readiness check: Azure (backend) and Google Play (mobile)

Checked on 18 October 2026 against `main` at commit `19f4e65`. Nothing was committed.

**Update, same day:** release tooling added: `tools/release/build-release.ps1` (both Play bundles, refuses localhost, http, a missing keystore or a `com.example` ID) and `backend/tools/azure/deploy-api.ps1` (App Service create, settings, deploy, `/health` check, custom domain). The client-facing short plan is the SmartMoney Go-Live Plan doc. Earlier, two items were then implemented in the working tree (uncommitted): a `/health` liveness endpoint (A9) and Azure Blob Storage for images behind a `Storage:Provider` switch, with provisioning and migration scripts for Azure Database for PostgreSQL and Blob Storage (A8). See `backend/docs/AZURE_MIGRATION.md`. Backend tests: 703 passed after the change.

## 1. Summary

| Target | Verdict |
|---|---|
| Backend to Azure | **Not ready to deploy as is.** Code builds in Release and all tests pass, but five production settings must exist before the app will even start, there are no migrations run at startup, and no Dockerfile or CI. The Azure move itself is now prepared in code and scripts (health endpoint added, Azure Blob Storage implemented, `tools/azure/provision.ps1` and `migrate-from-supabase.ps1` written) but has not been run: it needs `az login` and your choice of names and region. |
| Mobile to Play Store | **Not ready to upload.** The Android project is still the Flutter template: package name `com.example.smart_money_mobile`, app label `smart_money_mobile`, the stock Flutter launcher icon, no release keystore (release builds silently sign with the debug key), and the API base URL defaults to `https://localhost:7056` unless passed at build time. |

Two things could not be verified on this machine today, and are listed under "Not verified" rather than as app problems:

- The configured database (Supabase, `aws-1-ap-south-1.pooler.supabase.com`) is unreachable from the current mobile-hotspot network: TCP to ports 5432 and 6543 times out. The API therefore fails at startup (the role seeder is the first query). The end-to-end walk-through against real data was not possible.
- There is no Android SDK on this PC (`flutter doctor`: "Unable to locate Android SDK"), so `flutter build appbundle --release` cannot run here.

## 2. What was run and the result

| Check | Command | Result |
|---|---|---|
| Backend unit/handler tests | `dotnet test backend/tests/SmartMoney.Application.Tests` | **Passed: 689, failed: 0** (2 s). One build warning: MSB3277, EF Core Relational 10.0.4 vs 10.0.9 conflict in the test project (harmless, see warnings). |
| Mobile analyzer | `flutter analyze` in `smart_money_mobile` | **No issues found** |
| Mobile tests | `flutter test` in `smart_money_mobile` | **107 passed** |
| Admin analyzer | `flutter analyze` in `admin` | **No issues found** |
| Admin tests | `flutter test` in `admin` | **289 passed** |
| Backend production build | `dotnet publish src/SmartMoney.Api -c Release` | **Succeeded** (35 files). One warning: CA1416, the DPAPI call in `DependencyInjection.cs:180` is Windows-only; it is only reached when `DataProtection:UseDpapi=true`, so it is safe on Linux as long as that flag stays false. |
| Backend start (local, real config) | `dotnet run --launch-profile https` | **Failed**: `Npgsql.NpgsqlException: Failed to connect to 13.200.110.68:5432` (timeout) from `RoleSeeder.SeedAsync` at `Program.cs:232`. Network, not code. |
| Mobile app boot (web, debug) | `flutter run -d web-server --web-port 8088` | **Boots**: splash video, then the login screen renders. Log-in with the backend down shows the friendly message "Can't reach SmartMoney. Check your connection and try again." No app errors in the console (the only console error was the browser fetching `main.dart.js` before the first compile finished). |
| Admin app boot (web, debug) | `flutter run -d web-server --web-port 5180` | **Compiles and starts**, but the page stayed blank because CanvasKit is fetched from `www.gstatic.com`, which timed out on this network (`ERR_CONNECTION_TIMED_OUT`). Not an app bug; see warning A9 about bundling CanvasKit for hosted builds. |
| Android release bundle | `flutter build appbundle --release` | **Could not run**: "No Android SDK found. Try setting the ANDROID_HOME environment variable." |
| Scripted end-to-end (`backend/tools/e2e/run.mjs`) | not run | Needs the database; it would also leave two throwaway accounts in the Supabase database. |
| Flow walk-through (login, categories, stores, offers, search, admin dashboard and lists) | not possible | Backend cannot reach its database from this network. Last recorded full run: 11 October 2026 (89 scripted checks plus the manual round in `backend/tools/e2e/README.md`). |

## 3. Azure (backend)

### Blockers (the app will not start, or will not work, without these)

| # | Finding | Where | What to do |
|---|---|---|---|
| A1 | **No connection string outside Development.** `ConnectionStrings:DefaultConnection` lives only in .NET user secrets, which are not loaded in Production. Startup throws "Connection string 'DefaultConnection' was not found." | `DependencyInjection.cs:33` | Set `ConnectionStrings__DefaultConnection` as an App Service setting (or Key Vault reference). Decide whether this points at Supabase or at a new Azure Database for PostgreSQL; the milestones say Azure, the code and secrets still say Supabase. |
| A2 | **JWT signing key, super-admin email and Cuelinks webhook token are user secrets only.** Startup throws "JWT secret key was not configured." | `DependencyInjection.cs:201-225`, `SuperAdminSeeder.cs`, `WebhooksController.cs:56` | Set `Jwt__SecretKey` (at least 32 bytes, random), `Seed__SuperAdminEmail`, `Webhooks__CuelinksToken`. Use different values from local ones. |
| A3 | **Email (SMTP) is mandatory outside Development.** With `Email:Host` empty the app throws "Email is not configured" at startup, by design. No SMTP values exist locally today. | `DependencyInjection.cs:76-98`, `Program.cs:222` | Set `Email__Host`, `Email__Port`, `Email__Username`, `Email__Password`, `Email__FromAddress`. Test a signup OTP on the deployed instance before opening the app to users. |
| A4 | **Data Protection key ring is mandatory outside Development.** `PayoutStartupValidator` refuses to start without `DataProtection:KeysPath`, and without key encryption (`CertificatePath` + `CertificatePassword`, `UseDpapi` on Windows, or the explicit `AllowUnencryptedKeys=true`). Bank details for withdrawals are encrypted with these keys; losing them makes open withdrawals unreadable. | `PayoutStartupValidator.cs:52-71` | On App Service Linux set `DataProtection__KeysPath=/home/data-protection-keys` (the `/home` share persists across restarts) and either upload a PFX and set `CertificatePath`/`CertificatePassword`, or set `AllowUnencryptedKeys=true` knowingly. Better long term: Azure Key Vault key protection (`Azure.Extensions.AspNetCore.DataProtection.Keys`). Do not set `UseDpapi` on Linux. |
| A5 | **Reverse-proxy headers are off by default**, so behind App Service's TLS-terminating front end the app sees every request as plain HTTP. `UseHttpsRedirection` then answers 307 for everything, which gives a redirect loop, and rate limits key on the proxy IP instead of the client. | `Program.cs:76-91`, `Program.cs:263-266` | Set `ForwardedHeaders__TrustAllProxies=true` (the code's own documented opt-in). Confirm with a `curl -I https://<host>/api/categories` that there is no 307. |
| A6 | **CORS allows no browser origin in Production.** `Cors:AllowedOrigins` is empty; the any-origin fallback only applies in Development. The admin web app (and any Flutter web build) will be blocked. The native Android app is not affected. | `Program.cs:52-72` | Set `Cors__AllowedOrigins__0=https://<admin host>` (and more indexes for more hosts). |
| A7 | **Migrations are not applied at startup** (no `Migrate()` call, which is a sensible choice), so a fresh Azure database has no schema and startup fails at the first query. | `Program.cs:226-240` | Before the first deploy, and after every migration, run `dotnet ef database update --project src/SmartMoney.Infrastructure --startup-project src/SmartMoney.Api` against the Azure database, or generate `dotnet ef migrations script --idempotent` and run it. Take a backup first. |
| A8 | **Media storage was Supabase-only** and its URL/key are not set anywhere. **Code done, infrastructure pending:** `Storage:Provider=AzureBlob` now selects `AzureBlobProfilePhotoStorage` / `AzureBlobCatalogueMediaStorage` (`src/SmartMoney.Api/Storage/`), with startup validation and 14 tests. Default stays `Supabase` so nothing changes until you opt in. | `MediaStorageRegistration.cs`, `AzureBlobObjectStore.cs`, `appsettings.json` | Run `backend/tools/azure/provision.ps1` (after `az login`), then `migrate-from-supabase.ps1` to copy the database, images and rewrite the stored URLs. Runbook: `backend/docs/AZURE_MIGRATION.md`. |

| A20 | **Cuelinks live tracking: code done 20 Oct, switch-on pending.** `CuelinksAffiliateNetworkClient` now calls the official V3 Convert Link API (`POST /pub_api/v3/links/convert`, `subid` = tracking reference, optional `channel_id`) and falls back to the untracked link on any failure; the postback accepts GET, form POST and JSON with Cuelinks' macro names, the secret as header, query or body field (never stored), and the `payable` status. Remaining: create the V3 key and Global Postback (Azure Server Guide, Step 13) and prove one real purchase. Original finding: **Cuelinks live tracking was not implemented, so no commission would be earned.** With no API key the server uses `MockAffiliateNetworkClient`, which only appends `?subid=` to the store's own URL (not a Cuelinks tracked link). Setting `AffiliateNetworks:Cuelinks:ApiKey` switches to `CuelinksAffiliateNetworkClient`, whose `BuildTrackedUrlAsync` throws `NotSupportedException`, so every click would fail. The postback contract in `WebhooksController` was modelled on public docs and never verified. | `Infrastructure/Affiliate/CuelinksAffiliateNetworkClient.cs`, `Api/Controllers/WebhooksController.cs` | Rupankar's Cuelinks account exists (stated 18 Oct). Get the API key, channel ID and postback documentation from Cuelinks, then implement the link call and align the postback mapping. Prove it with one real purchase before public launch. Runbook: Azure Server Guide, Step 13. |

| A21 | **The GitHub repositories are public.** RoySujay-dev/SMARTMONEY, sujaydevroy/SMARTMONEY and roytushar55-lab/SMARTMONEY returned 200 from the public GitHub API on 20 Oct. They expose the client's code, documents and `backend/tools/e2e/README.md`, which lists test account passwords including a SuperAdmin that exists in the Supabase database. Commit a1d6d66 holds an old Supabase password and JWT key; both were checked and differ from the current ones. | GitHub | Move to a private repository in the client's GitHub (Azure Server Guide, Step 14), make the old ones private or delete them, and deactivate the example.com test accounts (Step 4) before the database goes live. |

### Warnings (should fix, or decide consciously)

| # | Finding | What to do |
|---|---|---|
| A9 | ~~No health endpoint.~~ **Done:** `GET /health` returns `200 Healthy` (`Program.cs`, `AddHealthChecks` + `MapHealthChecks`). Liveness only, no database check, so a database blip does not make App Service restart the app. Not hit at runtime here because the API cannot reach its database from this network. | Set the App Service health check path to `/health`. |
| A10 | **Done 20 Oct:** `deploy-api.ps1` for the first deploy and settings; `.github/workflows/ci.yml` (pull requests: backend tests, both Flutter apps) and `deploy-api.yml` (push to main: test, publish, deploy with OpenID Connect, /health check); `setup-github-oidc.ps1` for the one-time trust. Runbook: Azure Server Guide, Step 14. Original finding: **No Dockerfile, no deployment script, no GitHub workflow** (`.github/workflows` is empty). | Pick one: App Service code deploy (`az webapp up` or zip deploy of the `dotnet publish` output, runtime `DOTNETCORE:10.0`), or a Dockerfile plus Container Apps / App Service for Containers. Add a workflow that runs `dotnet test` and both `flutter analyze`/`flutter test` before deploying. |
| A11 | **Background worker needs the process alive.** `WithdrawalWorker` is a `BackgroundService` (retries and reconciles automatic payouts; idle for the Manual provider). On App Service it stops when the site is unloaded. | Turn on **Always On** (Basic tier or above), or accept it for the Manual provider. |
| A12 | **Logging is console only** at `Information`. No Application Insights, no request logging, no correlation IDs. The exception handler hides details from clients (good) but also does not log them. | Enable App Service log streaming at least; add Application Insights (`Microsoft.ApplicationInsights.AspNetCore`) and log the exception inside the `UseExceptionHandler` lambda. |
| A13 | **Startup does destructive work every boot**: the deleted-account archive purge (`ExecuteDeleteAsync`) and seeders run before the app listens. On Azure with slot swaps and scale-out this runs on every instance. It is idempotent, but a slow DB makes startup time out. | Acceptable for one instance; move the purge to a scheduled job before scaling out. |
| A14 | **Payouts provider is `Manual` and the privacy policy and terms name Cashfree** as the provider (`docs/legal/PRIVACY_POLICY.md:52,88,98`, `TERMS_OF_SERVICE.md:80-81`). | Documented open decision (milestone M4). Update the legal documents before the Play listing links to them. |
| A15 | **Rate limits and consent IPs depend on A5.** Without trusted forwarded headers every client shares the proxy's IP and the global 300/min limit would throttle all users together. | Covered by A5; verify after deploy by checking `RemoteIpAddress` in a log line. |
| A16 | **Swagger is Development-only** (good) but there is no API documentation for production. `AllowedHosts` is `*`. | Fine for launch. Consider restricting `AllowedHosts` to the API host name. |
| A17 | **Connection string has no explicit `SSL Mode`.** Npgsql's default (`Prefer`) will connect unencrypted if the server allows it. Azure Database for PostgreSQL enforces TLS; Supabase pooler does too. | Add `;SSL Mode=Require` (or `VerifyFull` with the CA) to the production connection string. |
| A18 | **Test project build warning MSB3277**: `Microsoft.EntityFrameworkCore.Relational` 10.0.4 (transitive via `Microsoft.AspNetCore.OpenApi` 10.0.8 / Npgsql 10.0.3) vs 10.0.9 (`Microsoft.EntityFrameworkCore.Design`). | Align the EF packages (`Microsoft.EntityFrameworkCore.Design`, `Tools` and the runtime) on one version. Cosmetic today. |
| A19 | **Admin web build fetches CanvasKit from `www.gstatic.com`** at runtime. Hosting the admin app where that CDN is slow or blocked gives a blank page (seen today). | Build hosted web apps with `flutter build web --no-web-resources-cdn` so CanvasKit is served with the app. |

### Settings the API needs on Azure (App Service "Environment variables", or Key Vault references)

```
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__DefaultConnection=Host=...;Database=...;Username=...;Password=...;SSL Mode=Require
Jwt__SecretKey=<random, 32+ bytes>
Seed__SuperAdminEmail=<your admin account email>
Webhooks__CuelinksToken=<the token configured in Cuelinks>
Email__Host, Email__Port, Email__Username, Email__Password, Email__FromAddress
DataProtection__KeysPath=/home/data-protection-keys
DataProtection__CertificatePath + DataProtection__CertificatePassword   (or DataProtection__AllowUnencryptedKeys=true)
ForwardedHeaders__TrustAllProxies=true
Cors__AllowedOrigins__0=https://<admin web host>
Storage__Provider=AzureBlob
AzureBlobStorage__ConnectionString=<from provision.ps1>   (or AzureBlobStorage__AccountUrl with a managed identity)
   (to stay on Supabase instead: Storage__Provider=Supabase plus SupabaseStorage__Url and SupabaseStorage__ServiceRoleKey)
AffiliateNetworks__Cuelinks__ApiKey                                        (optional; without it the mock affiliate client is used)
Payouts__Provider=Manual                                                   (default; Fake is refused outside Development)
```

## 4. Google Play (smart_money_mobile)

### Blockers

| # | Finding | Where | What to do |
|---|---|---|---|
| P1 | **Package name is the template default** `com.example.smart_money_mobile` (namespace, `applicationId`, Kotlin package folder). Play Console rejects `com.example` application IDs, and the ID cannot be changed after the first upload. | `android/app/build.gradle.kts:19,29`, `android/app/src/main/kotlin/com/example/smart_money_mobile/MainActivity.kt` | Choose a permanent ID (for example `in.smartmoney.app`), change `namespace`, `applicationId`, the Kotlin `package` line and folder path. `flutter_secure_storage` and `shared_preferences` are keyed by package, so do this before any user installs the app. (iOS has the same `com.example.smartMoneyMobile` bundle ID; out of scope but note it.) |
| P2 | **No release keystore.** `android/key.properties` and any `.jks` are absent (correctly not committed). The Gradle file then falls back to the **debug** signing key with only a log warning, so `flutter build appbundle --release` "succeeds" with a bundle Play will reject, and a later real key would not match. | `android/app/build.gradle.kts:46-56` | Create an upload keystore (`keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`), store it outside the repo plus a backup, create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, and confirm `.gitignore` covers both (it currently does **not** list `key.properties` or `*.jks`; add them). Enrol in Play App Signing. |
| P3 | **API base URL defaults to `https://localhost:7056`** and nothing stops a release build from shipping with it. On a phone the app would show "Can't reach SmartMoney" for everything. | `lib/core/network/api_config.dart:12-15` | Always build with `flutter build appbundle --release --dart-define=API_BASE_URL=https://<api host>`. Put that command in a script or CI step so it cannot be forgotten. The API host must be HTTPS: the manifest sets `usesCleartextTraffic="false"`, so plain HTTP is refused. |
| P4 | **App name shown on the device is `smart_money_mobile`.** | `android/app/src/main/AndroidManifest.xml:6` (`android:label`) | Set `android:label="SmartMoney"`. |
| P5 | **Launcher icon is the stock Flutter logo** (all five `mipmap-*/ic_launcher.png` files are byte-identical to the Flutter template). | `android/app/src/main/res/mipmap-*` | Generate icons from `assets/images/smartmoney_mark.png` (for example with the `flutter_launcher_icons` package, including an adaptive icon), and a 512x512 store icon plus feature graphic for the listing. |
| P6 | **Release bundle not built.** No Android SDK on this PC. | environment | Install Android Studio or the command-line tools, set `ANDROID_HOME`, run `flutter doctor --android-licenses`, then build. Expect the first build to download Gradle 9.1 and AGP 9.0.1 (several hundred MB; mind the metered hotspot). Check the build log for R8 "missing class" errors; `proguard-rules.pro` is empty, which is normally fine for `http`, `flutter_secure_storage`, `video_player`, `image_picker` and `url_launcher`, but it has never been exercised. |
| P7 | **Privacy policy URL and account-deletion URL are required by Play Console** and neither is hosted yet (milestone M6: "Host the four legal HTML pages at public addresses"). The policy promises in-app deletion (section 13), which exists (`delete_account_screen.dart`), but Play also requires a public web page describing deletion for apps with account creation. | `docs/legal/*.html` | Host `privacy-policy.html` and `terms-of-service.html` (for example on Azure Static Web Apps or the API's `wwwroot`), add a short "delete your account" page, and point the in-app Terms/Privacy rows at them. Update the Cashfree and effective-date wording first (A14). |

### Looks right

| Item | Value |
|---|---|
| `versionName` / `versionCode` | `1.0.0` / `1` from `pubspec.yaml` (`version: 1.0.0+1`). Bump the `+N` for every upload. |
| `minSdk` / `targetSdk` / `compileSdk` | 24 / 36 / 36 from Flutter 3.44.8 defaults. Play's current requirement (target API 35 or higher for new apps since 31 August 2025; 36 expected from the August 2026 deadline) is met. |
| Permissions | `INTERNET` only. `image_picker` uses the Android photo picker, so no storage or camera permission is declared. Good for the Data Safety form. |
| Network security | `android:usesCleartextTraffic="false"`, `android:allowBackup="false"`. |
| Build type | R8 minify and resource shrinking on in release; Java 17; Kotlin 2.3.20; AGP 9.0.1; Gradle 9.1. |
| Code hygiene | Analyzer clean, 107 tests pass, one `debugPrint` in `auth_session_service.dart:47` that logs only the error text of a failed token read, not the token (stripped in release builds). No secrets in the Dart code. |
| Legal copies | `assets/legal/privacy_policy.md` and `terms_of_service.md` bundled with consent version 2026-10-05, matching the backend. |

### Warnings

| # | Finding | What to do |
|---|---|---|
| P8 | `pubspec.yaml` description is "A new Flutter project." and `web/manifest.json`/`index.html` still say `smart_money_mobile`. Cosmetic for Play, visible if the web build is ever hosted. | Rename. |
| P9 | `admin/` Android project: template `applicationId` `com.example.smartmoney_admin`, label `smartmoney_admin`, and no `INTERNET` permission in the main manifest, so a release build could not reach the API at all. **Fixed (uncommitted):** `INTERNET` permission, `allowBackup=false`, cleartext off, and `key.properties` release signing like the user app. The ID and label still wait for the client's choice. | The admin app ships on a Play closed testing track (decided 18 Oct). Check its layout on a phone before the first upload. |
| P10 | Data Safety form: the app collects email, phone, name, optional profile photo, payout details (UPI/bank), signup IP and consent record, and sends affiliate click IDs to Cuelinks. | Declare these; say data is encrypted in transit and that users can request deletion. |
| P11 | Google Play target audience: the terms require users to be 18+. | Set the target age group to 18+ in the content rating and "Target audience" sections; avoid anything that looks aimed at children. |

## 5. Manual checklist

### Before deploying the backend
- [ ] Decided: move to Azure first. `az login`, then `backend/tools/azure/provision.ps1` and `migrate-from-supabase.ps1` (runbook: `backend/docs/AZURE_MIGRATION.md`). The restore carries the EF migrations history, so A7 only applies to future migrations.
- [ ] Create the App Service (Linux, .NET 10) or Container App; turn on Always On and HTTPS Only; add a custom domain (`api.smart-money.in`) with a managed certificate.
- [ ] Add every setting in section 3 ("Settings the API needs"), preferably as Key Vault references. Generate a new JWT key and webhook token for production.
- [ ] Set up SMTP (A3) and send yourself a signup OTP from the deployed API.
- [ ] Upload or generate the Data Protection certificate (A4) and keep an offline copy; document that rotating it strands open withdrawals.
- [ ] Deploy (`dotnet publish -c Release` then zip deploy, or a container), then check: `GET /api/categories` returns 200 over HTTPS with no 307; a login works; an admin login works; the admin web app can call the API (CORS).
- [ ] Point the Cuelinks postback URL at the production webhook and do one real conversion test (milestone M5).
- [ ] Register the super-admin account, restart once so `SuperAdminSeeder` promotes it.

### Before uploading to Play
- [ ] Install the Android SDK on the build machine (P6).
- [ ] Change the application ID (P1), app label (P4) and icons (P5).
- [ ] Create the upload keystore and `android/key.properties` (P2). `.gitignore` now covers `key.properties`, `*.jks` and `*.keystore`.
- [ ] Build with `flutter build appbundle --release --dart-define=API_BASE_URL=https://api.smart-money.in` (P3) and install the resulting bundle on a real device via `bundletool` or an internal-testing track; sign up, verify OTP, browse, click an offer, check the wallet.
- [ ] Host the privacy policy, terms and account-deletion pages (P7); update them for the final payout provider, hosting provider and effective date.
- [ ] Play Console: create the app, fill Data Safety (P10), content rating, target audience 18+ (P11), add the privacy policy and deletion URLs, store listing assets (512x512 icon, 1024x500 feature graphic, phone screenshots), enrol in Play App Signing, then release to Internal testing first.

## 6. Not verified today, and how to verify

| Item | Why not | How |
|---|---|---|
| Login, browsing, search, admin dashboard and lists against real data | Supabase ports 5432/6543 blocked on the hotspot network | On a network where `Test-NetConnection aws-1-ap-south-1.pooler.supabase.com -Port 5432` succeeds, run `backend/tools/e2e/start-api.cmd` (safe overrides: console OTP, SMTP disabled) and the two Flutter apps from `.claude/launch.json`, then sign in with the test accounts in `backend/tools/e2e/README.md`. Or run `node backend/tools/e2e/run.mjs` for the scripted 89-check money path. |
| `flutter build appbundle --release` | No Android SDK on this PC | Install the SDK, then rerun. |
| R8/ProGuard behaviour of the release build | Same | Same, then smoke-test the release build on a device. |
| SMTP delivery from production | No SMTP settings exist yet | After A3. |
