# SmartMoney on Azure: UAT and PROD

Built on 23 October 2026. Supabase is retired: the data and images were
copied into Azure and Supabase is no longer used by any environment.

## 1. What exists

All in resource group `smartmoney-rg`, Central India, subscription
"Azure subscription 1" (a free trial until 17 November 2026: upgrade to
pay-as-you-go before then or everything stops).

| Piece | UAT | PROD | Shared |
|---|---|---|---|
| API (App Service, Linux, .NET 10) | `smartmoney-api-uat` | `smartmoney-api-prod` | plan `smartmoney-plan` (B1) |
| Address | `smartmoney-api-uat.azurewebsites.net` (later `uat-api.smart-money.in`) | `smartmoney-api-prod.azurewebsites.net` (later `api.smart-money.in`) | |
| Database | `smartmoney_uat` | `smartmoney_prod` | server `smartmoney-pg` (PostgreSQL 17, Burstable B1ms, 32 GB, 7-day backups) |
| Database logins | `sm_uat_owner`, `sm_uat_app` | `sm_prod_owner`, `sm_prod_app` | admin `smartmoney_admin` (setup only) |
| Images (blob storage) | `smartmoneymediauat` | `smartmoneymediaprod` | containers `profile-images`, `catalogue-media` (public read of single files) |

Approximate cost: ₹1,261 (plan) + ₹1,717 (database compute) + ₹300-400
(database storage) + a few rupees of blob storage a month. UAT adds almost
nothing because it shares the plan and the database server.

### Database rules (backend/tools/azure/setup-database.sql)

- Tables live in schema `smartmoney`, not `public`. Connection strings set
  `Search Path=smartmoney`; no code change was needed.
- `sm_<env>_owner` owns the tables and is used only for migrations.
- `sm_<env>_app` is what the API uses: read and write rows only (no
  `CREATE`, `DROP`, `ALTER` or `TRUNCATE`).
- Each database accepts only its own environment's two logins.
- The server has public network access on, but the firewall allows only
  Azure services (the web apps) and the operator's IP (`AllowOperatorIp`).
  Update that rule when your IP changes:
  `.\provision.ps1 -MyPublicIp (Invoke-RestMethod https://api.ipify.org) -SkipDatabaseSetup`.

### Secrets

Everything secret lives in `D:\SmartMoney-Secrets` (outside the repo):
admin and per-login passwords, `connections-uat.txt` and
`connections-prod.txt` (API and owner connection strings, storage connection
string), `jwt-<env>.txt`, `cuelinks-token-<env>.txt`, `brevo-smtp-key.txt`.
Move them into a password manager. The settings files
`backend/tools/azure/uat.settings.json` and `prod.settings.json` are made from
them by `write-settings.ps1` and are git-ignored.

## 2. Signing in from the dev PC

The tenant's Security Defaults block `az login` for the owner account
(AADSTS530035), so scripts use a service principal with Contributor rights:

```powershell
$env:SM_SP_SECRET = Read-Host "Service principal password"
az login --service-principal --username <appId> --password $env:SM_SP_SECRET --tenant 96ed315f-9a63-40d4-8136-1c0a266e6f1d
```

Contributor cannot create app registrations or assign roles: run
`setup-github-oidc.ps1` in the Azure portal's Cloud Shell as the owner.

## 3. Scripts (backend/tools/azure)

| Script | Does |
|---|---|
| `provision.ps1` | Resource group, database server, both databases with logins and schema, both storage accounts. Re-runnable. |
| `migrate-from-supabase.ps1 -Environment uat\|prod` | Copied Supabase into an environment: tables into `smartmoney`, refresh tokens and stale codes dropped, test accounts off in prod, row counts checked, images copied, URLs rewritten. Kept for reference; Supabase is retired. |
| `write-settings.ps1 -Environment uat\|prod -AdminEmail <email>` | Builds the git-ignored settings file from the secrets folder. |
| `deploy-api.ps1 -AppName smartmoney-api-<env> -SettingsFile .\<env>.settings.json` | Creates the web app if needed, applies settings, builds, deploys, waits for `/health`. `-SkipSettings` / `-SkipCode` to do one half. `-CustomDomain <host>` binds a domain with a free certificate. |
| `setup-github-oidc.ps1 -Branch dev\|main -WebAppName ...` | One-time GitHub-to-Azure trust per environment (run in Cloud Shell). |

## 4. Deploying

Normal path (GitHub Actions, `.github/workflows/deploy-api.yml`):

- pull request into `dev`, merged: UAT deploys;
- pull request from `dev` into `main`, merged: PROD deploys.

The free GitHub plan cannot block direct pushes, so always use pull
requests. Database migrations are not run by the workflow: apply them with
the owner login, UAT first, before merging code that needs them:

```powershell
dotnet ef database update --project src/SmartMoney.Infrastructure --startup-project src/SmartMoney.Api `
  --connection "<owner connection string from connections-<env>.txt>"
```

Manual path (same result, from the dev PC): `deploy-api.ps1` as above.

Changing a setting: edit the secrets or run `write-settings.ps1`, then
`deploy-api.ps1 ... -SkipCode`.

## 5. Problems met while building it (and the fixes now in the scripts)

| Symptom | Cause | Fix |
|---|---|---|
| `az` warnings made PowerShell 5.1 stop | Redirected stderr becomes a terminating error | `Invoke-Az` judges only by the exit code |
| "the following arguments are required: --server-name" | Azure CLI 2.90 renamed arguments | Firewall and database commands use `--server-name` / `--name` |
| "Firewall rule operations are not supported for a server without public access" | `--public-access None` now creates the server with public access disabled | `provision.ps1` switches public access on (still limited by the firewall) |
| App setting rejected: "AppSetting with name 'AzureBlobStorage__ConnectionString' is not allowed" | App Service reserves names starting with `AzureBlobStorage` | Config section renamed to `BlobStorage` |
| Zip deploy failed in rsync (Kudu 400) | PowerShell 5.1 `Compress-Archive` writes backslash paths | `deploy-api.ps1` builds the zip with forward slashes |
| Settings arrived as `@{value=...; PSPath=...}` | `Get-Content` lines carry hidden properties into `ConvertTo-Json` | `write-settings.ps1` splits the raw file text |

## 6. Local development

The API's user secrets on the dev PC still point at the old Supabase
database. Point them at the UAT database (with the UAT app login and this
PC's IP in the firewall) or at a local PostgreSQL instead; Supabase will be
shut down.
