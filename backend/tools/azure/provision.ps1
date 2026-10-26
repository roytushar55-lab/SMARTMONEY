<#
.SYNOPSIS
  Creates the Azure resources for SmartMoney UAT and PROD: one resource
  group, one PostgreSQL flexible server holding a database per environment
  (each with its own owner and app logins and a dedicated "smartmoney"
  schema), and one image storage account per environment.

.DESCRIPTION
  Idempotent: anything that already exists is reused, so a failed run can
  simply be repeated. The App Service plan and the two web apps are created
  by deploy-api.ps1; data is copied by migrate-from-supabase.ps1.

  Secrets (server admin password, per-environment database passwords,
  connection strings, storage connection strings) are generated here and
  written to -SecretsDir, outside the repository. Nothing secret is printed.
  Move them into a password manager.

  Needs: Azure CLI signed in (az login or a service principal with
  Contributor), and psql (PostgreSQL client 16+) for the database setup.

.EXAMPLE
  .\provision.ps1 -MyPublicIp (Invoke-RestMethod https://api.ipify.org)
#>
[CmdletBinding()]
param(
    [string] $ResourceGroup = "smartmoney-rg",
    [string] $Location = "centralindia",

    [string] $PostgresServerName = "smartmoney-pg",
    [string] $PostgresAdminUser = "smartmoney_admin",
    [string] $PostgresVersion = "17",
    [string] $PostgresSku = "Standard_B1ms",
    [int] $PostgresStorageGb = 32,

    [string[]] $Environments = @("uat", "prod"),
    # Storage account per environment: <prefix><environment>, e.g. smartmoneymediauat.
    [string] $StoragePrefix = "smartmoneymedia",
    [string] $ProfilePhotosContainer = "profile-images",
    [string] $CatalogueContainer = "catalogue-media",

    # Your public IP, so this PC can run the database setup and the data copy.
    [string] $MyPublicIp,

    [string] $SecretsDir = "D:\SmartMoney-Secrets",
    [string] $PgBinDir = "C:\Program Files\PostgreSQL\18\bin",
    [switch] $SkipDatabaseSetup
)

$ErrorActionPreference = "Stop"

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

# Windows PowerShell 5.1 turns redirected native stderr into a terminating
# error under Stop, so quiet lookups run with Continue locally.
function Test-AzExists {
    $ErrorActionPreference = "Continue"
    & az @args --only-show-errors 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Get-AzQuiet {
    $ErrorActionPreference = "Continue"
    $output = & az @args --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $output
}

# Letters and digits only, so the value never needs escaping in a connection
# string, a URL or a shell. 32 characters is about 190 bits.
function New-Secret([int] $Length = 32) {
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $bytes = New-Object byte[] ($Length * 2)
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $sb = New-Object Text.StringBuilder
    foreach ($b in $bytes) {
        if ($sb.Length -ge $Length) { break }
        if ($b -lt (256 - (256 % $chars.Length))) { [void]$sb.Append($chars[$b % $chars.Length]) }
    }
    return $sb.ToString()
}

# Returns the secret stored in $SecretsDir\<name>.txt, creating it once.
function Get-OrCreateSecret([string] $Name) {
    $path = Join-Path $SecretsDir "$Name.txt"
    if (Test-Path $path) { return (Get-Content $path -Raw).Trim() }
    $value = New-Secret
    Set-Content -Path $path -Value $value -NoNewline -Encoding ascii
    return $value
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw "Azure CLI (az) is not installed." }
$accountJson = Get-AzQuiet account show
$account = if ($accountJson) { ($accountJson -join "`n") | ConvertFrom-Json } else { $null }
if (-not $account) { throw "Not signed in. Run: az login (or az login --service-principal ...)" }
Write-Host "Subscription: $($account.name) ($($account.id))" -ForegroundColor Cyan

$psql = Join-Path $PgBinDir "psql.exe"
if (-not $SkipDatabaseSetup -and -not (Test-Path $psql)) { throw "psql not found at $psql. Set -PgBinDir." }

New-Item -ItemType Directory -Force $SecretsDir | Out-Null
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
if ((Resolve-Path $SecretsDir).Path.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "SecretsDir must be outside the repository ($repoRoot)."
}

# 0. Resource providers (free; new subscriptions start with them off)
foreach ($provider in "Microsoft.Web", "Microsoft.DBforPostgreSQL", "Microsoft.Storage") {
    $state = Get-AzQuiet provider show --namespace $provider --query registrationState --output tsv
    if ($state -ne "Registered") {
        Write-Host "Registering $provider (a minute or two)..."
        Invoke-Az provider register --namespace $provider --wait --output none
    }
}

# 1. Resource group
if (Test-AzExists group show --name $ResourceGroup) {
    Write-Host "Resource group $ResourceGroup exists."
} else {
    Write-Host "Creating resource group $ResourceGroup in $Location..."
    Invoke-Az group create --name $ResourceGroup --location $Location --output none
}

# 2. PostgreSQL flexible server (shared by UAT and PROD)
$adminPassword = Get-OrCreateSecret "postgres-admin-password"
if (Test-AzExists postgres flexible-server show --resource-group $ResourceGroup --name $PostgresServerName) {
    Write-Host "Postgres server $PostgresServerName exists."
} else {
    Write-Host "Creating Postgres flexible server $PostgresServerName ($PostgresSku, v$PostgresVersion)... (5-10 minutes)"
    Invoke-Az postgres flexible-server create `
        --resource-group $ResourceGroup `
        --name $PostgresServerName `
        --location $Location `
        --admin-user $PostgresAdminUser `
        --admin-password $adminPassword `
        --version $PostgresVersion `
        --tier Burstable `
        --sku-name $PostgresSku `
        --storage-size $PostgresStorageGb `
        --backup-retention 7 `
        --public-access None `
        --yes `
        --output none
}

# Public network access must be on for firewall rules to apply. Only the
# addresses in the rules below can connect; everything else is refused.
$publicAccess = Get-AzQuiet postgres flexible-server show --resource-group $ResourceGroup --name $PostgresServerName --query "network.publicNetworkAccess" --output tsv
if ($publicAccess -ne "Enabled") {
    Write-Host "Enabling public network access (restricted by the firewall rules below)..."
    Invoke-Az postgres flexible-server update --resource-group $ResourceGroup --name $PostgresServerName `
        --public-access Enabled --yes --output none
}

Write-Host "Firewall: Azure services (the web apps)$(if ($MyPublicIp) { " and this PC ($MyPublicIp)" })..."
Invoke-Az postgres flexible-server firewall-rule create `
    --resource-group $ResourceGroup --server-name $PostgresServerName `
    --name AllowAzureServices `
    --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none
if ($MyPublicIp) {
    Invoke-Az postgres flexible-server firewall-rule create `
        --resource-group $ResourceGroup --server-name $PostgresServerName `
        --name AllowOperatorIp `
        --start-ip-address $MyPublicIp --end-ip-address $MyPublicIp --output none
}

$pgHost = "$PostgresServerName.postgres.database.azure.com"
$summary = @()

foreach ($envName in $Environments) {
    $envName = $envName.ToLowerInvariant()
    $database = "smartmoney_$envName"
    $ownerRole = "sm_${envName}_owner"
    $appRole = "sm_${envName}_app"
    $storageAccount = "$StoragePrefix$envName"

    Write-Host ""
    Write-Host "== $($envName.ToUpperInvariant())" -ForegroundColor Cyan

    # 3. Database
    if (Test-AzExists postgres flexible-server db show --resource-group $ResourceGroup --server-name $PostgresServerName --name $database) {
        Write-Host "Database $database exists."
    } else {
        Write-Host "Creating database $database..."
        Invoke-Az postgres flexible-server db create `
            --resource-group $ResourceGroup --server-name $PostgresServerName `
            --name $database --output none
    }

    # 4. Logins, schema and grants (setup-database.sql)
    $ownerPassword = Get-OrCreateSecret "postgres-$ownerRole-password"
    $appPassword = Get-OrCreateSecret "postgres-$appRole-password"
    if (-not $SkipDatabaseSetup) {
        Write-Host "Setting up logins $ownerRole / $appRole and schema smartmoney..."
        $env:PGPASSWORD = $adminPassword
        $env:SM_OWNER_PASSWORD = $ownerPassword
        $env:SM_APP_PASSWORD = $appPassword
        try {
            & $psql "host=$pgHost port=5432 dbname=$database user=$PostgresAdminUser sslmode=require connect_timeout=15" `
                -X -q -v ON_ERROR_STOP=1 -v "owner=$ownerRole" -v "app=$appRole" -v "db=$database" -v "admin=$PostgresAdminUser" `
                -f (Join-Path $PSScriptRoot "setup-database.sql")
            if ($LASTEXITCODE -ne 0) { throw "Database setup for $database failed. Is this PC's IP in the firewall (-MyPublicIp)?" }
        }
        finally {
            $env:PGPASSWORD = $null
            $env:SM_OWNER_PASSWORD = $null
            $env:SM_APP_PASSWORD = $null
        }
    }

    # 5. Image storage
    if (Test-AzExists storage account show --resource-group $ResourceGroup --name $storageAccount) {
        Write-Host "Storage account $storageAccount exists."
    } else {
        Write-Host "Creating storage account $storageAccount..."
        Invoke-Az storage account create `
            --resource-group $ResourceGroup --name $storageAccount --location $Location `
            --sku Standard_LRS --kind StorageV2 --access-tier Hot `
            --min-tls-version TLS1_2 --allow-blob-public-access true --https-only true `
            --output none
    }
    $storageKey = Invoke-Az storage account keys list --resource-group $ResourceGroup --account-name $storageAccount --query "[0].value" --output tsv
    foreach ($container in @($ProfilePhotosContainer, $CatalogueContainer)) {
        Invoke-Az storage container create --account-name $storageAccount --account-key $storageKey `
            --name $container --public-access blob --output none | Out-Null
    }
    $storageConnection = Invoke-Az storage account show-connection-string `
        --resource-group $ResourceGroup --name $storageAccount --query connectionString --output tsv

    # 6. Connection strings for this environment (secrets file)
    $common = "Host=$pgHost;Database=$database;SSL Mode=Require;Search Path=smartmoney"
    $lines = @(
        "# SmartMoney $($envName.ToUpperInvariant()) - generated by provision.ps1. Keep secret.",
        "API (App Service setting ConnectionStrings__DefaultConnection):",
        "$common;Username=$appRole;Password=$appPassword",
        "",
        "Migrations only (dotnet ef / psql), never in App Service:",
        "$common;Username=$ownerRole;Password=$ownerPassword",
        "",
        "BlobStorage__ConnectionString:",
        $storageConnection
    )
    $file = Join-Path $SecretsDir "connections-$envName.txt"
    Set-Content -Path $file -Value $lines -Encoding utf8
    $summary += [pscustomobject]@{ Environment = $envName; Database = $database; Storage = $storageAccount; Secrets = $file }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
$summary | Format-Table -AutoSize
Write-Host "Server admin password: $(Join-Path $SecretsDir 'postgres-admin-password.txt'). Move all files in $SecretsDir to a password manager."
Write-Host "Next: .\migrate-from-supabase.ps1 -Environment uat, then -Environment prod."
