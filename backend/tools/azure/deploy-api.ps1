<#
.SYNOPSIS
  Creates (first run) or updates (later runs) the SmartMoney API on Azure App
  Service for Linux, applies the production settings, deploys the code and
  checks /health. Re-run it for every release.

.DESCRIPTION
  First run creates, in the existing resource group:
    - an App Service plan (Linux, B1 by default) and a web app on .NET 10;
    - HTTPS only, Always On (keeps the withdrawal worker running), FTP off,
      health check path /health.
  Every run:
    - applies the settings from prod.settings.json (secrets; git-ignored);
    - dotnet publish -c Release, zip, deploy;
    - waits for GET /health to answer "Healthy".
  With -CustomDomain it also prints the DNS records to add and, once they
  exist, binds the domain with a free App Service managed certificate.

  Run `az login` first, with an account that has Owner or Contributor on
  the resource group.

.EXAMPLE
  .\deploy-api.ps1 -ResourceGroup smartmoney-prod -AppName smartmoney-api
  .\deploy-api.ps1 -ResourceGroup smartmoney-prod -AppName smartmoney-api -CustomDomain api.smart-money.in
  .\deploy-api.ps1 -NewJwtKey      # just prints a random JWT signing key
#>
[CmdletBinding(DefaultParameterSetName = "Deploy")]
param(
    [Parameter(Mandatory, ParameterSetName = "Deploy")] [string] $ResourceGroup,
    # Globally unique; becomes <AppName>.azurewebsites.net.
    [Parameter(Mandatory, ParameterSetName = "Deploy")] [string] $AppName,
    [Parameter(ParameterSetName = "Deploy")] [string] $Location = "centralindia",
    [Parameter(ParameterSetName = "Deploy")] [string] $PlanName = "smartmoney-plan",
    [Parameter(ParameterSetName = "Deploy")] [string] $PlanSku = "B1",
    [Parameter(ParameterSetName = "Deploy")] [string] $Runtime = "DOTNETCORE:10.0",
    [Parameter(ParameterSetName = "Deploy")] [string] $SettingsFile = (Join-Path $PSScriptRoot "prod.settings.json"),
    [Parameter(ParameterSetName = "Deploy")] [string] $CustomDomain,
    [Parameter(ParameterSetName = "Deploy")] [switch] $SkipSettings,
    [Parameter(ParameterSetName = "Deploy")] [switch] $SkipCode,

    [Parameter(Mandatory, ParameterSetName = "Key")] [switch] $NewJwtKey
)

$ErrorActionPreference = "Stop"

if ($NewJwtKey) {
    $bytes = New-Object byte[] 48
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    Write-Output ([Convert]::ToBase64String($bytes))
    return
}

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

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw "Azure CLI (az) is not installed." }
$accountJson = Get-AzQuiet account show
$account = if ($accountJson) { ($accountJson -join "`n") | ConvertFrom-Json } else { $null }
if (-not $account) { throw "Not signed in. Run: az login" }
Write-Host "Subscription: $($account.name)" -ForegroundColor Cyan

if (-not (Test-AzExists group show --name $ResourceGroup)) {
    throw "Resource group '$ResourceGroup' not found, or you have no access to it. The owner creates it and grants you Owner (see the Go-Live Plan)."
}

# 1. Plan and web app (first run only)
if (-not (Test-AzExists appservice plan show --resource-group $ResourceGroup --name $PlanName)) {
    Write-Host "Creating App Service plan $PlanName ($PlanSku, Linux)..."
    Invoke-Az appservice plan create --resource-group $ResourceGroup --name $PlanName `
        --location $Location --sku $PlanSku --is-linux --output none
}

if (-not (Test-AzExists webapp show --resource-group $ResourceGroup --name $AppName)) {
    Write-Host "Creating web app $AppName ($Runtime)..."
    Invoke-Az webapp create --resource-group $ResourceGroup --plan $PlanName --name $AppName `
        --runtime $Runtime --output none
}

Write-Host "Applying platform settings (HTTPS only, Always On, FTP off, health check)..."
Invoke-Az webapp update --resource-group $ResourceGroup --name $AppName --https-only true --output none
Invoke-Az webapp config set --resource-group $ResourceGroup --name $AppName `
    --always-on true --ftps-state Disabled --min-tls-version 1.2 --http20-enabled true `
    --generic-configurations "healthCheckPath=/health" --output none

# 2. App settings
if (-not $SkipSettings) {
    if (-not (Test-Path $SettingsFile)) {
        throw "Settings file $SettingsFile not found. Copy prod.settings.example.json to prod.settings.json and fill it in."
    }
    $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
    $placeholders = @($settings.PSObject.Properties | Where-Object { "$($_.Value)" -match '<[^>]+>' } | ForEach-Object Name)
    $optional = @("AffiliateNetworks__Cuelinks__ApiKey", "AffiliateNetworks__Cuelinks__ChannelId")
    $missing = @($placeholders | Where-Object { $_ -notin $optional })
    if ($missing.Count -gt 0) {
        throw "Fill these settings in $SettingsFile first: $($missing -join ', ')"
    }

    $list = @()
    foreach ($p in $settings.PSObject.Properties) {
        if ($p.Name -in $placeholders) { continue }   # optional and still a placeholder: skip
        $list += @{ name = $p.Name; value = "$($p.Value)"; slotSetting = $false }
    }
    if ($CustomDomain) {
        $list += @{ name = "AllowedHosts"; value = "$CustomDomain;$AppName.azurewebsites.net"; slotSetting = $false }
    }

    $tmp = New-TemporaryFile
    try {
        $list | ConvertTo-Json -Depth 3 | Set-Content -Path $tmp -Encoding utf8
        Write-Host "Applying $($list.Count) app settings..."
        Invoke-Az webapp config appsettings set --resource-group $ResourceGroup --name $AppName `
            --settings "@$tmp" --output none
    }
    finally {
        Remove-Item $tmp -Force
    }
}

# 3. Build and deploy
if (-not $SkipCode) {
    $project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\src\SmartMoney.Api\SmartMoney.Api.csproj")).Path
    $work = Join-Path ([IO.Path]::GetTempPath()) "smartmoney-deploy-$([guid]::NewGuid().ToString('N'))"
    $publish = Join-Path $work "publish"
    $zip = Join-Path $work "api.zip"
    try {
        Write-Host "dotnet publish -c Release..."
        & dotnet publish $project -c Release -o $publish --nologo -v q
        if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }
        Compress-Archive -Path (Join-Path $publish "*") -DestinationPath $zip
        Write-Host "Deploying $([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB..."
        Invoke-Az webapp deploy --resource-group $ResourceGroup --name $AppName `
            --src-path $zip --type zip --async false --output none
    }
    finally {
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 4. Health check
$hostName = "$AppName.azurewebsites.net"
$healthUrl = "https://$hostName/health"
Write-Host "Waiting for $healthUrl ..."
$healthy = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $r = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 20
        if ($r.StatusCode -eq 200 -and $r.Content -match "Healthy") { $healthy = $true; break }
    }
    catch { }
    Start-Sleep -Seconds 10
}
if (-not $healthy) {
    Write-Host "Not healthy after 5 minutes. Startup errors (missing setting, database firewall) show in the log stream:" -ForegroundColor Red
    Write-Host "  az webapp log tail --resource-group $ResourceGroup --name $AppName"
    exit 1
}
Write-Host "Healthy: $healthUrl" -ForegroundColor Green

# 5. Custom domain + free managed certificate
if ($CustomDomain) {
    $verificationId = Invoke-Az webapp show --resource-group $ResourceGroup --name $AppName `
        --query customDomainVerificationId --output tsv
    $label = $CustomDomain.Split(".")[0]

    $bound = Invoke-Az webapp config hostname list --resource-group $ResourceGroup --webapp-name $AppName `
        --query "[?name=='$CustomDomain'] | length(@)" --output tsv
    if ($bound -eq "0") {
        $added = Test-AzExists webapp config hostname add --resource-group $ResourceGroup --webapp-name $AppName `
            --hostname $CustomDomain --output none
        if (-not $added) {
            Write-Host ""
            Write-Host "Add these two DNS records at the domain registrar, wait 10-30 minutes, then run this script again:" -ForegroundColor Yellow
            Write-Host "  CNAME  $label        ->  $hostName"
            Write-Host "  TXT    asuid.$label  ->  $verificationId"
            exit 2
        }
    }

    Write-Host "Creating the free managed certificate for $CustomDomain..."
    $thumb = Get-AzQuiet webapp config ssl list --resource-group $ResourceGroup `
        --query "[?subjectName=='$CustomDomain'].thumbprint | [0]" --output tsv
    if (-not $thumb) {
        $thumb = Invoke-Az webapp config ssl create --resource-group $ResourceGroup --name $AppName `
            --hostname $CustomDomain --query thumbprint --output tsv
    }
    Invoke-Az webapp config ssl bind --resource-group $ResourceGroup --name $AppName `
        --certificate-thumbprint $thumb --ssl-type SNI --output none
    Write-Host "Bound https://$CustomDomain" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Next checks: sign in from the app, and trigger a password reset to confirm the OTP email arrives."
