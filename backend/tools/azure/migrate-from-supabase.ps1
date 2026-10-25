<#
.SYNOPSIS
  Copies the SmartMoney database from Supabase to Azure Database for
  PostgreSQL, uploads the images to Azure Blob Storage, and rewrites the
  stored image URLs to point at Azure.

.DESCRIPTION
  Steps, each skippable with a switch so a failed run can be resumed:
    1. pg_dump the public schema from Supabase (custom format, no owners or
       grants, so it restores cleanly under the Azure admin user).
    2. pg_restore it into the empty Azure database.
    3. Compare row counts for every table.
    4. Download every object in the two Supabase buckets (node
       copy-supabase-media.mjs) and upload them with az storage blob
       upload-batch.
    5. Rewrite the six image-URL columns from the Supabase public URL prefix
       to the Azure one.

  Nothing is changed in Supabase. Take the app offline (or accept that rows
  written after the dump are not copied) before running against production.

  Needs: PostgreSQL client tools (pg_dump, pg_restore, psql), Azure CLI
  signed in, Node 18+ for the media copy.

.EXAMPLE
  .\migrate-from-supabase.ps1 `
    -SourceConnection "postgresql://postgres.<ref>:<pw>@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" `
    -TargetConnection "postgresql://smartmoney_admin:<pw>@smartmoney-pg.postgres.database.azure.com:5432/smartmoney?sslmode=require" `
    -SupabaseUrl "https://<ref>.supabase.co" -SupabaseServiceRoleKey "<service role key>" `
    -StorageAccountName smartmoneymedia
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SourceConnection,
    [Parameter(Mandatory)] [string] $TargetConnection,

    [string] $SupabaseUrl,
    [string] $SupabaseServiceRoleKey,
    [string] $StorageAccountName,
    [string] $ProfilePhotosContainer = "profile-images",
    [string] $CatalogueContainer = "catalogue-media",
    # Set when a CDN or custom domain fronts the storage account.
    [string] $AzurePublicBaseUrl,

    [string] $PgBinDir = "C:\Program Files\PostgreSQL\18\bin",
    [string] $WorkDir = (Join-Path $PSScriptRoot "..\..\..\.migration"),

    [switch] $SkipDump,
    [switch] $SkipRestore,
    [switch] $SkipMedia,
    [switch] $SkipUrlRewrite
)

$ErrorActionPreference = "Stop"
$pgDump = Join-Path $PgBinDir "pg_dump.exe"
$pgRestore = Join-Path $PgBinDir "pg_restore.exe"
$psql = Join-Path $PgBinDir "psql.exe"
foreach ($tool in @($pgDump, $pgRestore, $psql)) {
    if (-not (Test-Path $tool)) { throw "Missing $tool. Set -PgBinDir to your PostgreSQL bin folder." }
}

New-Item -ItemType Directory -Force $WorkDir | Out-Null
$WorkDir = (Resolve-Path $WorkDir).Path
$dumpFile = Join-Path $WorkDir "smartmoney-public.dump"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# 1. Dump
if (-not $SkipDump) {
    Write-Host "1/5 Dumping public schema from Supabase to $dumpFile ..." -ForegroundColor Cyan
    & $pgDump --dbname=$SourceConnection --schema=public --format=custom `
        --no-owner --no-privileges --no-comments --file=$dumpFile
    if ($LASTEXITCODE -ne 0) { throw "pg_dump failed" }
    Write-Host "    $((Get-Item $dumpFile).Length / 1MB) MB"
}

# 2. Restore
if (-not $SkipRestore) {
    Write-Host "2/5 Restoring into Azure ..." -ForegroundColor Cyan
    $existing = & $psql --dbname=$TargetConnection --tuples-only --no-align `
        --command "select count(*) from information_schema.tables where table_schema='public';"
    if ($LASTEXITCODE -ne 0) { throw "Cannot reach the Azure database. Is your IP in the server firewall?" }
    if ([int]$existing.Trim() -gt 0) {
        throw "The Azure database already has $($existing.Trim()) tables in public. Drop them first (or use -SkipRestore)."
    }
    & $pgRestore --dbname=$TargetConnection --no-owner --no-privileges --exit-on-error $dumpFile
    if ($LASTEXITCODE -ne 0) { throw "pg_restore failed" }
}

# 3. Row counts
Write-Host "3/5 Comparing row counts ..." -ForegroundColor Cyan
$countSql = @"
select table_name, (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text::bigint as rows
from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name;
"@
$sourceCounts = & $psql --dbname=$SourceConnection --tuples-only --no-align --field-separator "|" --command $countSql
$targetCounts = & $psql --dbname=$TargetConnection --tuples-only --no-align --field-separator "|" --command $countSql
$mismatch = $false
$targetMap = @{}
foreach ($line in $targetCounts) { if ($line) { $parts = $line.Split('|'); $targetMap[$parts[0]] = $parts[1] } }
foreach ($line in $sourceCounts) {
    if (-not $line) { continue }
    $parts = $line.Split('|')
    $t = $targetMap[$parts[0]]
    $ok = ($t -eq $parts[1])
    if (-not $ok) { $mismatch = $true }
    Write-Host ("    {0,-32} supabase={1,8} azure={2,8} {3}" -f $parts[0], $parts[1], $t, $(if ($ok) { "ok" } else { "MISMATCH" }))
}
if ($mismatch) { throw "Row counts differ; stop and investigate before rewriting URLs." }

# 4. Media
$supabasePublicPrefix = $null
$azurePublicPrefix = $null
if ($SupabaseUrl -and $StorageAccountName) {
    $supabasePublicPrefix = "$($SupabaseUrl.TrimEnd('/'))/storage/v1/object/public"
    $azurePublicPrefix = if ($AzurePublicBaseUrl) { $AzurePublicBaseUrl.TrimEnd('/') } else { "https://$StorageAccountName.blob.core.windows.net" }
}

if (-not $SkipMedia) {
    if (-not ($SupabaseUrl -and $SupabaseServiceRoleKey -and $StorageAccountName)) {
        Write-Host "4/5 Skipping media copy: -SupabaseUrl, -SupabaseServiceRoleKey and -StorageAccountName are all needed." -ForegroundColor Yellow
    } else {
        Write-Host "4/5 Copying images ..." -ForegroundColor Cyan
        $mediaDir = Join-Path $WorkDir "media"
        $env:SUPABASE_URL = $SupabaseUrl
        $env:SUPABASE_SERVICE_ROLE_KEY = $SupabaseServiceRoleKey
        foreach ($bucket in @($ProfilePhotosContainer, $CatalogueContainer)) {
            $dest = Join-Path $mediaDir $bucket
            New-Item -ItemType Directory -Force $dest | Out-Null
            & node (Join-Path $PSScriptRoot "copy-supabase-media.mjs") $bucket $dest
            if ($LASTEXITCODE -ne 0) { throw "Downloading bucket $bucket failed" }
            if ((Get-ChildItem $dest -Recurse -File | Measure-Object).Count -eq 0) {
                Write-Host "    $bucket is empty, nothing to upload."
                continue
            }
            & az storage blob upload-batch --account-name $StorageAccountName --auth-mode login `
                --destination $bucket --source $dest --overwrite true --only-show-errors --output none
            if ($LASTEXITCODE -ne 0) { throw "Uploading $bucket failed (is 'Storage Blob Data Contributor' granted to your login?)" }
        }
        Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY
    }
}

# 5. URL rewrite
if (-not $SkipUrlRewrite) {
    if (-not $supabasePublicPrefix) {
        Write-Host "5/5 Skipping URL rewrite: -SupabaseUrl and -StorageAccountName are needed." -ForegroundColor Yellow
    } else {
        Write-Host "5/5 Rewriting image URLs $supabasePublicPrefix/... -> $azurePublicPrefix/... " -ForegroundColor Cyan
        $columns = @(
            @("Users", "ProfileImageUrl"),
            @("Stores", "LogoUrl"),
            @("Stores", "BannerUrl"),
            @("Offers", "ImageUrl"),
            @("Categories", "IconUrl"),
            @("Banners", "ImageUrl")
        )
        $sql = "begin;`n"
        foreach ($c in $columns) {
            $sql += "update ""$($c[0])"" set ""$($c[1])"" = replace(""$($c[1])"", '$supabasePublicPrefix/', '$azurePublicPrefix/') where ""$($c[1])"" like '$supabasePublicPrefix/%';`n"
        }
        $sql += "commit;`n"
        $sqlFile = Join-Path $WorkDir "rewrite-urls-$stamp.sql"
        Set-Content -Path $sqlFile -Value $sql -Encoding utf8
        & $psql --dbname=$TargetConnection --set ON_ERROR_STOP=1 --file $sqlFile
        if ($LASTEXITCODE -ne 0) { throw "URL rewrite failed (rolled back)" }
        $left = & $psql --dbname=$TargetConnection --tuples-only --no-align --command "select count(*) from ""Users"" where ""ProfileImageUrl"" like '$supabasePublicPrefix/%';"
        Write-Host "    Profile photos still on Supabase: $($left.Trim())"
    }
}

Write-Host ""
Write-Host "Migration finished. Point the API at Azure (ConnectionStrings__DefaultConnection, Storage__Provider=AzureBlob) and restart it." -ForegroundColor Green
Write-Host "The dump and downloaded images are in $WorkDir (git-ignored); delete them when you are happy."
