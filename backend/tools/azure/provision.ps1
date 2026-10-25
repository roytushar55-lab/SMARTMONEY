<#
.SYNOPSIS
  Creates the Azure resources SmartMoney needs: a resource group, an Azure
  Database for PostgreSQL flexible server with the application database, and
  a storage account with the two public-read blob containers for images.

.DESCRIPTION
  Idempotent: every "create" is skipped when the resource already exists, so
  the script can be re-run after a failure. It does NOT create the App
  Service (deploy the API however you prefer) and it does NOT move data; see
  migrate-from-supabase.ps1 for that.

  Run `az login` (and `az account set --subscription <id>`) first.

.EXAMPLE
  .\provision.ps1 -ResourceGroup smartmoney-prod -Location centralindia `
      -PostgresServerName smartmoney-pg -StorageAccountName smartmoneymedia `
      -MyPublicIp 203.0.113.7

  Prompts for the Postgres administrator password. Prints the two connection
  strings and the App Service settings to add at the end.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [string] $Location = "centralindia",

    # Must be globally unique, 3-63 chars, lowercase letters, digits and hyphens.
    [Parameter(Mandatory)] [string] $PostgresServerName,
    [string] $PostgresAdminUser = "smartmoney_admin",
    [SecureString] $PostgresAdminPassword,
    [string] $DatabaseName = "smartmoney",
    [string] $PostgresVersion = "17",
    # Burstable B1ms is enough to launch; scale up later without downtime.
    [string] $PostgresSku = "Standard_B1ms",
    [int] $PostgresStorageGb = 32,

    # Must be globally unique, 3-24 chars, lowercase letters and digits only.
    [Parameter(Mandatory)] [string] $StorageAccountName,
    [string] $ProfilePhotosContainer = "profile-images",
    [string] $CatalogueContainer = "catalogue-media",

    # Your current public IP, so you can run migrations and pg_restore from
    # this machine. Omit to open the database to Azure services only.
    [string] $MyPublicIp
)

$ErrorActionPreference = "Stop"

function Invoke-Az {
    $output = & az @args
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') failed (exit $LASTEXITCODE)" }
    return $output
}

# Runs az with errors silenced and returns $true when it exited 0. Windows
# PowerShell 5.1 turns redirected native stderr into a terminating error when
# $ErrorActionPreference is Stop, so this runs with Continue locally.
function Test-AzExists {
    $ErrorActionPreference = "Continue"
    & az @args --only-show-errors 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# Like Test-AzExists, but returns the command's output (or $null on failure).
function Get-AzQuiet {
    $ErrorActionPreference = "Continue"
    $output = & az @args --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $output
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed. https://aka.ms/installazurecliwindows"
}

$accountJson = Get-AzQuiet account show
$account = if ($accountJson) { ($accountJson -join "`n") | ConvertFrom-Json } else { $null }
if (-not $account) { throw "Not signed in. Run: az login" }
Write-Host "Subscription: $($account.name) ($($account.id))" -ForegroundColor Cyan

if (-not $PostgresAdminPassword) {
    $PostgresAdminPassword = Read-Host -AsSecureString "Postgres administrator password (16+ chars, letters, digits and symbols)"
}
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PostgresAdminPassword))

# 1. Resource group
if (Test-AzExists group show --name $ResourceGroup) {
    Write-Host "Resource group $ResourceGroup exists."
} else {
    Write-Host "Creating resource group $ResourceGroup in $Location..."
    Invoke-Az group create --name $ResourceGroup --location $Location --output none
}

# 2. PostgreSQL flexible server
if (Test-AzExists postgres flexible-server show --resource-group $ResourceGroup --name $PostgresServerName) {
    Write-Host "Postgres server $PostgresServerName exists."
} else {
    Write-Host "Creating Postgres flexible server $PostgresServerName ($PostgresSku, v$PostgresVersion)... (takes 5-10 minutes)"
    Invoke-Az postgres flexible-server create `
        --resource-group $ResourceGroup `
        --name $PostgresServerName `
        --location $Location `
        --admin-user $PostgresAdminUser `
        --admin-password $plainPassword `
        --version $PostgresVersion `
        --tier Burstable `
        --sku-name $PostgresSku `
        --storage-size $PostgresStorageGb `
        --backup-retention 7 `
        --public-access None `
        --yes `
        --output none
}

# Firewall: Azure services (the App Service) and, optionally, this machine.
Write-Host "Setting firewall rules..."
Invoke-Az postgres flexible-server firewall-rule create `
    --resource-group $ResourceGroup --name $PostgresServerName `
    --rule-name AllowAzureServices `
    --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none

if ($MyPublicIp) {
    Invoke-Az postgres flexible-server firewall-rule create `
        --resource-group $ResourceGroup --name $PostgresServerName `
        --rule-name AllowOperatorIp `
        --start-ip-address $MyPublicIp --end-ip-address $MyPublicIp --output none
}

if (Test-AzExists postgres flexible-server db show --resource-group $ResourceGroup --server-name $PostgresServerName --database-name $DatabaseName) {
    Write-Host "Database $DatabaseName exists."
} else {
    Write-Host "Creating database $DatabaseName..."
    Invoke-Az postgres flexible-server db create `
        --resource-group $ResourceGroup --server-name $PostgresServerName `
        --database-name $DatabaseName --output none
}

# 3. Storage account and containers
if (Test-AzExists storage account show --resource-group $ResourceGroup --name $StorageAccountName) {
    Write-Host "Storage account $StorageAccountName exists."
} else {
    Write-Host "Creating storage account $StorageAccountName..."
    Invoke-Az storage account create `
        --resource-group $ResourceGroup `
        --name $StorageAccountName `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --access-tier Hot `
        --min-tls-version TLS1_2 `
        --allow-blob-public-access true `
        --https-only true `
        --output none
}

$storageKey = (Invoke-Az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccountName --query "[0].value" --output tsv)

foreach ($container in @($ProfilePhotosContainer, $CatalogueContainer)) {
    Write-Host "Ensuring container $container (anonymous blob read)..."
    Invoke-Az storage container create `
        --account-name $StorageAccountName --account-key $storageKey `
        --name $container --public-access blob --output none
}

$storageConnectionString = (Invoke-Az storage account show-connection-string `
    --resource-group $ResourceGroup --name $StorageAccountName --query connectionString --output tsv)

$pgHost = "$PostgresServerName.postgres.database.azure.com"
$dbConnectionString = "Host=$pgHost;Database=$DatabaseName;Username=$PostgresAdminUser;Password=$plainPassword;SSL Mode=Require"

Write-Host ""
Write-Host "Done. App Service settings to add (Configuration > Environment variables):" -ForegroundColor Green
Write-Host "  ConnectionStrings__DefaultConnection = $dbConnectionString"
Write-Host "  Storage__Provider                    = AzureBlob"
Write-Host "  AzureBlobStorage__ConnectionString   = $storageConnectionString"
Write-Host "  (or, with a managed identity granted 'Storage Blob Data Contributor':)"
Write-Host "  AzureBlobStorage__AccountUrl         = https://$StorageAccountName.blob.core.windows.net"
Write-Host ""
Write-Host "Next: .\migrate-from-supabase.ps1 to copy the schema, data and images across." -ForegroundColor Yellow
Write-Host "Keep the passwords in a password manager; this script does not save them."
