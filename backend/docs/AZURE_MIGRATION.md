# Moving the database and images to Azure

The API talks to PostgreSQL through EF Core and Npgsql, so Azure Database for
PostgreSQL needs no code change: only the connection string moves. Images
(profile photos and admin-uploaded catalogue media) now have an Azure Blob
Storage implementation next to the Supabase one, chosen by `Storage:Provider`.

Everything below runs from your machine with the Azure CLI; nothing is
automatic on deploy.

## 0. What changed in the code

| Piece | Where |
|---|---|
| Provider switch (`Supabase`, default, or `AzureBlob`) | `src/SmartMoney.Api/Storage/MediaStorageRegistration.cs` |
| Azure settings (`AzureBlobStorage:*`) | `src/SmartMoney.Api/Storage/AzureBlobStorageOptions.cs`, defaults in `appsettings.json` |
| Blob upload, public URL, delete-by-URL | `AzureBlobObjectStore.cs`, wrapped by `AzureBlobProfilePhotoStorage.cs` and `AzureBlobCatalogueMediaStorage.cs` |
| Liveness probe | `GET /health` returns `200 Healthy` (no database check, on purpose) |
| Scripts | `tools/azure/provision.ps1`, `tools/azure/migrate-from-supabase.ps1`, `tools/azure/copy-supabase-media.mjs` |

Packages added to the API project: `Azure.Storage.Blobs`, `Azure.Identity`.

Both containers are created with anonymous **blob** read access, the same
model as Supabase's public buckets: anyone with a URL can read an image,
nobody can list or write. Uploads use a connection string or, better on App
Service, the system-assigned managed identity with the
"Storage Blob Data Contributor" role (then set `AzureBlobStorage:AccountUrl`
and leave `ConnectionString` empty).

## 1. Create the resources

```powershell
az login
az account set --subscription "<subscription name or id>"
cd backend\tools\azure
.\provision.ps1 -ResourceGroup smartmoney-prod -Location centralindia `
    -PostgresServerName smartmoney-pg -StorageAccountName smartmoneymedia `
    -MyPublicIp (Invoke-RestMethod https://api.ipify.org)
```

It creates (and skips what already exists):

- resource group;
- PostgreSQL flexible server, version 17, Burstable `Standard_B1ms`, 32 GB,
  7-day backups, public network with a firewall rule for Azure services and
  one for your IP; database `smartmoney`;
- StorageV2 account, LRS, HTTPS only, TLS 1.2, with containers
  `profile-images` and `catalogue-media` (public read of blobs).

It prints the two connection strings and the App Service settings. Nothing
is written to disk; store the passwords in your password manager.

Cost at launch sizing is roughly the B1ms server plus a few rupees of
storage; stop the server with `az postgres flexible-server stop` while not
in use (it auto-starts after 7 days).

## 2. Copy the data

Take the API offline first, or accept that rows written after the dump are
left behind. Then:

```powershell
.\migrate-from-supabase.ps1 `
  -SourceConnection "postgresql://postgres.<ref>:<pw>@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" `
  -TargetConnection "postgresql://smartmoney_admin:<pw>@smartmoney-pg.postgres.database.azure.com:5432/smartmoney?sslmode=require" `
  -SupabaseUrl "https://<ref>.supabase.co" -SupabaseServiceRoleKey "<service role key>" `
  -StorageAccountName smartmoneymedia
```

Steps, each resumable with `-SkipDump`, `-SkipRestore`, `-SkipMedia`,
`-SkipUrlRewrite`:

1. `pg_dump` of the `public` schema only (Supabase's `auth`, `storage` and
   other schemas are not ours), custom format, no owners or grants.
2. `pg_restore` into the empty Azure database. The `__EFMigrationsHistory`
   table comes with it, so `dotnet ef database update` afterwards is a no-op;
   future migrations apply normally.
3. Row counts for every table, Supabase vs Azure; stops on any difference.
4. Downloads every object from both buckets (`copy-supabase-media.mjs`, no
   dependencies) into `.migration/media/<bucket>/...` and uploads them with
   `az storage blob upload-batch`, same paths. Your `az login` account needs
   "Storage Blob Data Contributor" on the account for this step.
5. Rewrites the six URL columns (`Users.ProfileImageUrl`, `Stores.LogoUrl`,
   `Stores.BannerUrl`, `Offers.ImageUrl`, `Categories.IconUrl`,
   `Banners.ImageUrl`) from
   `https://<ref>.supabase.co/storage/v1/object/public/<bucket>/...` to
   `https://smartmoneymedia.blob.core.windows.net/<bucket>/...` in one
   transaction, and reports how many profile photos still point at Supabase
   (should be 0).

Images served from the API's own `wwwroot/media` are not affected; they
deploy with the app.

The working folder `.migration/` at the repo root is git-ignored. Delete it
once you are happy; it contains a full copy of the database.

## 3. Point the API at Azure

App Service settings (or Key Vault references):

```
ConnectionStrings__DefaultConnection = Host=smartmoney-pg.postgres.database.azure.com;Database=smartmoney;Username=smartmoney_admin;Password=<pw>;SSL Mode=Require
Storage__Provider                    = AzureBlob
AzureBlobStorage__ConnectionString   = <from provision.ps1>
      or
AzureBlobStorage__AccountUrl         = https://smartmoneymedia.blob.core.windows.net   (managed identity)
```

Locally, the same keys as user secrets (`dotnet user-secrets set
"Storage:Provider" "AzureBlob"` and so on) switch a dev machine over; leave
them unset to keep using Supabase.

Then restart, open `/health` (expect `Healthy`), sign in, open a store with
a logo (loads from the blob URL), upload a profile photo (lands in
`profile-images`), and upload a store logo from the admin app (lands in
`catalogue-media`).

## 4. Afterwards

- Keep Supabase read-only for a week, then delete the project so the old
  URLs stop working on purpose rather than silently.
- Set the App Service health check path to `/health`.
- Consider a CDN or custom domain (`media.smart-money.in`) in front of the
  storage account; set `AzureBlobStorage:PublicBaseUrl` to it and re-run the
  URL rewrite step with `-AzurePublicBaseUrl`.
- The privacy policy already names Azure as the hosting provider; no change
  needed there for storage.
