<#
.SYNOPSIS
  Copies the SmartMoney data from Supabase into one Azure environment (uat
  or prod): tables into the "smartmoney" schema owned by that environment's
  owner login, a data clean-up, grants for the app login, row-count checks,
  the images from Supabase Storage into the environment's blob storage, and
  the image URLs rewritten to Azure.

.DESCRIPTION
  Run provision.ps1 first. Then:
    .\migrate-from-supabase.ps1 -Environment uat
    .\migrate-from-supabase.ps1 -Environment prod

  Steps:
    1. pg_dump Supabase's public schema once (cached in .migration\, git-ignored).
       Supabase's own schemas (auth, storage, realtime, vault) are not copied.
    2. Restore as the owner login, then move every table into "smartmoney".
    3. Clean up: drop all refresh tokens (everyone signs in again on the new
       server), used or expired one-time codes, and legacy /uploads/ photo
       paths; in prod also switch off the example.com and test.local accounts.
    4. Grant the app login read/write on the tables.
    5. Compare row counts with Supabase.
    6. Copy the Supabase Storage objects (public buckets, so no Supabase key
       is needed) to the environment's storage account and rewrite URLs.
    7. Check EF's migration history matches the latest migration in the code.

  Nothing in Supabase is changed. Rows written to Supabase after the dump
  are not copied, so stop using Supabase before the prod run.

  Needs: PostgreSQL client tools 16+, Azure CLI signed in (Contributor is
  enough: blob uploads use the storage account key), the API's user secret
  ConnectionStrings:DefaultConnection pointing at Supabase (or -SourceConnection).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet("uat", "prod")] [string] $Environment,

    [string] $ResourceGroup = "smartmoney-rg",
    [string] $PostgresServerName = "smartmoney-pg",
    [string] $PostgresAdminUser = "smartmoney_admin",
    [string] $StoragePrefix = "smartmoneymedia",
    [string] $SecretsDir = "D:\SmartMoney-Secrets",

    # Npgsql-style Supabase connection string. Default: the API's user secret.
    [string] $SourceConnection,

    [string] $PgBinDir = "C:\Program Files\PostgreSQL\18\bin",
    [string] $WorkDir = (Join-Path $PSScriptRoot "..\..\..\.migration"),

    # Take a new dump instead of reusing the cached one.
    [switch] $FreshDump,
    # Drop the tables already in the target (only before go-live!).
    [switch] $ResetTarget,
    [switch] $SkipMedia
)

$ErrorActionPreference = "Stop"
# Windows PowerShell 5.1 may default to old TLS versions; Supabase needs 1.2+.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# psql and pg_restore must not see a UTF-8 byte-order mark.
$Utf8NoBom = New-Object Text.UTF8Encoding($false)
$pgDump = Join-Path $PgBinDir "pg_dump.exe"
$pgRestore = Join-Path $PgBinDir "pg_restore.exe"
$psql = Join-Path $PgBinDir "psql.exe"
foreach ($tool in @($pgDump, $pgRestore, $psql)) {
    if (-not (Test-Path $tool)) { throw "Missing $tool. Set -PgBinDir." }
}

# Runs az and returns its normal output. Judged only by the exit code:
# Windows PowerShell 5.1 would otherwise treat any az warning on stderr as a
# fatal error. On failure the stderr text is included in the exception.
function Invoke-Az {
    $ErrorActionPreference = "Continue"
    $all = & az @args --only-show-errors 2>&1
    $code = $LASTEXITCODE
    $errors = @($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
    $output = @($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    if ($code -ne 0) {
        throw "az $(($args | Select-Object -First 4) -join ' ') ... failed (exit $code): $($errors -join ' ')"
    }
    return $output
}

# "Host=..;Database=..;Username=..;Password=.." -> hashtable (lower-case keys)
function ConvertFrom-NpgsqlConnection([string] $Value) {
    $kv = @{}
    foreach ($part in $Value.Split(';')) {
        if ($part -match '^\s*([^=]+?)\s*=\s*(.*)$') { $kv[$Matches[1].ToLowerInvariant()] = $Matches[2] }
    }
    return $kv
}

# libpq connection string without the password (it travels in PGPASSWORD).
function Get-ConnInfo($kv) {
    $port = if ($kv['port']) { $kv['port'] } else { '5432' }
    return "host=$($kv['host']) port=$port dbname=$($kv['database']) user=$($kv['username']) sslmode=require connect_timeout=15"
}

# Runs psql against a connection hashtable; returns stdout lines.
function Invoke-Psql($kv, [string[]] $PsqlArgs) {
    $env:PGPASSWORD = $kv['password']
    try {
        $out = & $psql (Get-ConnInfo $kv) -X -q -v ON_ERROR_STOP=1 @PsqlArgs
        if ($LASTEXITCODE -ne 0) { throw "psql failed against $($kv['host'])/$($kv['database'])" }
        return $out
    }
    finally { $env:PGPASSWORD = $null }
}

function Invoke-Sql($kv, [string] $Sql) {
    $file = Join-Path $WorkDir ("step-" + [guid]::NewGuid().ToString('N') + ".sql")
    [IO.File]::WriteAllText($file, $Sql, $Utf8NoBom)
    try { return Invoke-Psql $kv @('-At', '-f', $file) }
    finally { Remove-Item $file -Force }
}

New-Item -ItemType Directory -Force $WorkDir | Out-Null
$WorkDir = (Resolve-Path $WorkDir).Path

# Connections
if (-not $SourceConnection) {
    $SourceConnection = (& dotnet user-secrets list --project (Join-Path $PSScriptRoot "..\..\src\SmartMoney.Api") |
        Where-Object { $_ -like 'ConnectionStrings:DefaultConnection*' }) -replace '^ConnectionStrings:DefaultConnection = ', ''
    if (-not $SourceConnection) { throw "No -SourceConnection and no user secret ConnectionStrings:DefaultConnection." }
}
$source = ConvertFrom-NpgsqlConnection $SourceConnection
if ($source['username'] -notmatch '^postgres\.(?<ref>[a-z0-9]+)$') { throw "Source does not look like a Supabase pooler login (postgres.<project ref>)." }
$supabaseRef = $Matches['ref']

$connFile = Join-Path $SecretsDir "connections-$Environment.txt"
if (-not (Test-Path $connFile)) { throw "$connFile not found. Run provision.ps1 first." }
$ownerLine = Get-Content $connFile | Where-Object { $_ -match "Username=sm_${Environment}_owner;" } | Select-Object -First 1
$appLine = Get-Content $connFile | Where-Object { $_ -match "Username=sm_${Environment}_app;" } | Select-Object -First 1
$owner = ConvertFrom-NpgsqlConnection $ownerLine
$appRole = (ConvertFrom-NpgsqlConnection $appLine)['username']
$admin = @{
    host = $owner['host']; port = '5432'; database = $owner['database']
    username = $PostgresAdminUser
    password = (Get-Content (Join-Path $SecretsDir "postgres-admin-password.txt") -Raw).Trim()
}
$storageAccount = "$StoragePrefix$Environment"
Write-Host "Copying Supabase ($supabaseRef) -> $($owner['host'])/$($owner['database']) [$Environment]" -ForegroundColor Cyan

# 1. Dump (cached)
$dumpFile = Join-Path $WorkDir "supabase-public.dump"
if ($FreshDump -or -not (Test-Path $dumpFile)) {
    Write-Host "1/7 Dumping Supabase public schema..." -ForegroundColor Cyan
    $env:PGPASSWORD = $source['password']
    try {
        & $pgDump (Get-ConnInfo $source) --schema=public --format=custom --no-owner --no-privileges --no-comments --file=$dumpFile
        if ($LASTEXITCODE -ne 0) { throw "pg_dump failed" }
    }
    finally { $env:PGPASSWORD = $null }
} else {
    Write-Host "1/7 Reusing dump from $((Get-Item $dumpFile).LastWriteTime) (use -FreshDump for a new one)." -ForegroundColor Cyan
}

# 2. Restore as the owner, then move the tables into smartmoney
Write-Host "2/7 Restoring into $($owner['database'])..." -ForegroundColor Cyan
$existing = (Invoke-Sql $owner "select count(*) from pg_tables where schemaname in ('smartmoney','public');" | Select-Object -Last 1).Trim()
if ([int]$existing -gt 0) {
    if (-not $ResetTarget) { throw "Target already has $existing tables. Re-run with -ResetTarget to replace them (only before go-live)." }
    Write-Host "    -ResetTarget: dropping $existing existing tables."
    Invoke-Sql $owner @"
do `$`$ declare r record; begin
  for r in select schemaname, tablename from pg_tables where schemaname in ('smartmoney','public') and tableowner = current_user loop
    execute format('drop table if exists %I.%I cascade', r.schemaname, r.tablename);
  end loop; end `$`$;
"@ | Out-Null
}

# The dump would also try to create schema "public"; restore everything else.
$fullList = Join-Path $WorkDir "restore-full.list"
$list = Join-Path $WorkDir "restore-$Environment.list"
$tocLines = & $pgRestore -l $dumpFile
if ($LASTEXITCODE -ne 0) { throw "pg_restore -l failed" }
[IO.File]::WriteAllLines($fullList, [string[]]$tocLines, $Utf8NoBom)
$kept = @($tocLines | Where-Object { $_ -notmatch ' SCHEMA - public ' -and $_ -notmatch 'COMMENT - SCHEMA public' })
[IO.File]::WriteAllLines($list, [string[]]$kept, $Utf8NoBom)

Invoke-Sql $admin "grant usage, create on schema public to $($owner['username']);" | Out-Null
try {
    $env:PGPASSWORD = $owner['password']
    try {
        $dbArg = "--dbname=" + (Get-ConnInfo $owner)
        & $pgRestore $dbArg --no-owner --no-privileges --exit-on-error "--use-list=$list" $dumpFile
        if ($LASTEXITCODE -ne 0) { throw "pg_restore failed" }
    }
    finally { $env:PGPASSWORD = $null }

    Invoke-Sql $owner @"
do `$`$ declare r record; begin
  for r in select tablename from pg_tables where schemaname = 'public' and tableowner = current_user loop
    execute format('alter table public.%I set schema smartmoney', r.tablename);
  end loop; end `$`$;
"@ | Out-Null
}
finally {
    Invoke-Sql $admin "revoke usage, create on schema public from $($owner['username']);" | Out-Null
}
$moved = (Invoke-Sql $owner "select count(*) from pg_tables where schemaname = 'smartmoney';" | Select-Object -Last 1).Trim()
Write-Host "    $moved tables now in schema smartmoney."

# 3. Clean-up
Write-Host "3/7 Cleaning data..." -ForegroundColor Cyan
$prodOnly = if ($Environment -eq 'prod') {
    "update ""Users"" set ""IsActive"" = false where ""IsActive"" and (""Email"" like '%@example.com' or ""Email"" like '%@test.local');"
} else { "" }
$cleanup = Invoke-Sql $owner @"
set search_path = smartmoney;
begin;
with d as (delete from "RefreshTokens" returning 1) select 'refresh tokens removed: ' || count(*) from d;
with d as (delete from "EmailVerificationOtps" where "IsUsed" or "ExpiresAt" < now() returning 1) select 'used/expired sign-up codes removed: ' || count(*) from d;
with d as (delete from "PasswordResetOtps" where "IsUsed" or "ExpiresAt" < now() returning 1) select 'used/expired reset codes removed: ' || count(*) from d;
with u as (update "Users" set "ProfileImageUrl" = null where "ProfileImageUrl" like '/uploads/%' returning 1) select 'legacy photo paths cleared: ' || count(*) from u;
$prodOnly
select 'active test accounts left: ' || count(*) from "Users" where "IsActive" and ("Email" like '%@example.com' or "Email" like '%@test.local');
commit;
"@
$cleanup | Where-Object { $_ } | ForEach-Object { Write-Host "    $_" }

# 4. Grants for the app login
Write-Host "4/7 Granting $appRole read/write on the tables..." -ForegroundColor Cyan
Invoke-Sql $owner @"
grant select, insert, update, delete on all tables in schema smartmoney to $appRole;
grant usage, select, update on all sequences in schema smartmoney to $appRole;
"@ | Out-Null

# 5. Row counts
Write-Host "5/7 Comparing row counts with Supabase..." -ForegroundColor Cyan
$countSql = "select table_name || '|' || (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text from information_schema.tables where table_schema = '{0}' and table_type = 'BASE TABLE' order by 1;"
$sourceMap = @{}; foreach ($l in (Invoke-Sql $source ($countSql -f 'public'))) { if ($l -match '\|') { $p = $l.Split('|'); $sourceMap[$p[0]] = [int]$p[1] } }
$targetMap = @{}; foreach ($l in (Invoke-Sql $owner ($countSql -f 'smartmoney'))) { if ($l -match '\|') { $p = $l.Split('|'); $targetMap[$p[0]] = [int]$p[1] } }
$cleaned = @('RefreshTokens', 'EmailVerificationOtps', 'PasswordResetOtps')
$problems = 0
foreach ($t in ($sourceMap.Keys | Sort-Object)) {
    $s = $sourceMap[$t]; $a = $targetMap[$t]
    $state = if ($a -eq $s) { "ok" } elseif ($t -in $cleaned -and $a -le $s) { "cleaned" } else { $problems++; "MISMATCH" }
    Write-Host ("    {0,-26} supabase={1,6} azure={2,6} {3}" -f $t, $s, $a, $state)
}
if ($problems -gt 0) { throw "$problems table(s) differ; investigate before using this database." }

# 6. Images
if (-not $SkipMedia) {
    Write-Host "6/7 Copying images to $storageAccount..." -ForegroundColor Cyan
    $objects = Invoke-Sql $source "select bucket_id || '/' || name from storage.objects where bucket_id in ('profile-images','catalogue-media') order by 1;"
    $mediaDir = Join-Path $WorkDir "media"
    $supabasePrefix = "https://$supabaseRef.supabase.co/storage/v1/object/public"
    foreach ($o in ($objects | Where-Object { $_ })) {
        $target = Join-Path $mediaDir ($o -replace '/', '\')
        if (-not (Test-Path $target)) {
            New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
            Invoke-WebRequest -Uri "$supabasePrefix/$o" -OutFile $target -UseBasicParsing -TimeoutSec 60
        }
    }
    $key = Invoke-Az storage account keys list --resource-group $ResourceGroup --account-name $storageAccount --query "[0].value" --output tsv
    foreach ($bucket in 'profile-images', 'catalogue-media') {
        $dir = Join-Path $mediaDir $bucket
        if (-not (Test-Path $dir)) { continue }
        Invoke-Az storage blob upload-batch --account-name $storageAccount --account-key $key `
            --destination $bucket --source $dir --overwrite true --only-show-errors --output none | Out-Null
        Write-Host "    $($bucket): $((Get-ChildItem $dir -Recurse -File).Count) files uploaded."
    }

    $azurePrefix = "https://$storageAccount.blob.core.windows.net"
    $columns = @(@('Users','ProfileImageUrl'), @('Stores','LogoUrl'), @('Stores','BannerUrl'), @('Offers','ImageUrl'), @('Categories','IconUrl'), @('Banners','ImageUrl'))
    $sql = "set search_path = smartmoney;`nbegin;`n"
    foreach ($c in $columns) {
        $sql += "update ""$($c[0])"" set ""$($c[1])"" = replace(""$($c[1])"", '$supabasePrefix/', '$azurePrefix/') where ""$($c[1])"" like '$supabasePrefix/%';`n"
    }
    $sql += "commit;`n"
    foreach ($c in $columns) {
        $sql += "select 'still on Supabase in $($c[0]).$($c[1]): ' || count(*) from ""$($c[0])"" where ""$($c[1])"" like '%supabase.co%';`n"
    }
    Invoke-Sql $owner $sql | Where-Object { $_ } | ForEach-Object { Write-Host "    $_" }
}

# 7. EF migration history vs the code
Write-Host "7/7 Checking EF migration history..." -ForegroundColor Cyan
$latestInCode = Get-ChildItem (Join-Path $PSScriptRoot "..\..\src\SmartMoney.Infrastructure\Persistence\Migrations") -Filter "*.cs" |
    Where-Object { $_.Name -match '^\d{14}_.+\.cs$' -and $_.Name -notmatch '\.Designer\.cs$' } |
    ForEach-Object { $_.BaseName } | Sort-Object | Select-Object -Last 1
$latestInDb = (Invoke-Sql $owner "select max(""MigrationId"") from smartmoney.""__EFMigrationsHistory"";" | Select-Object -Last 1).Trim()
Write-Host "    code: $latestInCode"
Write-Host "    db:   $latestInDb"
if ($latestInCode -ne $latestInDb) {
    Write-Warning "The database is not on the latest migration. Apply it with the owner connection before deploying."
}

Write-Host ""
Write-Host "Done: $Environment is ready for the API." -ForegroundColor Green
Write-Host "API connection string and storage connection string: $connFile"
