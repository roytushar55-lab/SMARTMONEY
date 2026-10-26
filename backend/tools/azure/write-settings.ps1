<#
.SYNOPSIS
  Writes uat.settings.json or prod.settings.json (git-ignored) for
  deploy-api.ps1 from the secrets provision.ps1 created, plus a JWT key and
  a Cuelinks webhook token generated once per environment.

.DESCRIPTION
  Secrets read from / written to -SecretsDir (outside the repo):
    connections-<env>.txt        from provision.ps1 (API connection, storage)
    jwt-<env>.txt                generated once; changing it signs everyone out
    cuelinks-token-<env>.txt     generated once; also goes into Cuelinks' postback
    brevo-smtp-key.txt           put the Brevo SMTP key here yourself (optional:
                                 without it the API runs but cannot send codes)
    cuelinks-api-key.txt         optional; without it the test client is used

.EXAMPLE
  .\write-settings.ps1 -Environment uat  -AdminEmail roysujay584@gmail.com
  .\write-settings.ps1 -Environment prod -AdminEmail rupankarde678@gmail.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet("uat", "prod")] [string] $Environment,
    [Parameter(Mandatory)] [string] $AdminEmail,
    [string] $SmtpHost = "smtp-relay.brevo.com",
    [int] $SmtpPort = 587,
    [string] $SmtpUsername = "bc99b6001@smtp-brevo.com",
    [string] $SmtpFromAddress = "admin@smart-money.in",
    [string] $SmtpFromName = "Smart Money",
    [string] $SecretsDir = "D:\SmartMoney-Secrets"
)

$ErrorActionPreference = "Stop"

function Get-OrCreate([string] $Name, [int] $Bytes) {
    $path = Join-Path $SecretsDir "$Name.txt"
    if (Test-Path $path) { return (Get-Content $path -Raw).Trim() }
    $buffer = New-Object byte[] $Bytes
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    # URL-safe base64: fine in a query string (Cuelinks postback) and as a JWT key.
    $value = [Convert]::ToBase64String($buffer).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    Set-Content -Path $path -Value $value -NoNewline -Encoding ascii
    return $value
}

function Get-Optional([string] $Name) {
    $path = Join-Path $SecretsDir "$Name.txt"
    if (Test-Path $path) { return (Get-Content $path -Raw).Trim() }
    return $null
}

$connFile = Join-Path $SecretsDir "connections-$Environment.txt"
if (-not (Test-Path $connFile)) { throw "$connFile not found. Run provision.ps1 first." }
# -split on the raw text gives plain strings. Lines from Get-Content carry
# hidden PSPath/ReadCount properties that ConvertTo-Json would serialise.
$lines = @((Get-Content $connFile -Raw) -split "`r?`n")
$apiConnection = $lines | Where-Object { $_ -match "Username=sm_${Environment}_app;" } | Select-Object -First 1
$storageIndex = [Array]::IndexOf($lines, "BlobStorage__ConnectionString:")
if ($storageIndex -lt 0) { $storageIndex = [Array]::IndexOf($lines, "AzureBlobStorage__ConnectionString:") }  # files written before the rename
$storageConnection = if ($storageIndex -ge 0) { $lines[$storageIndex + 1] } else { $null }
if (-not $apiConnection -or -not $storageConnection) { throw "Could not read the connection strings from $connFile." }

$settings = [ordered]@{
    "ASPNETCORE_ENVIRONMENT"               = "Production"
    "ConnectionStrings__DefaultConnection" = $apiConnection
    "Jwt__SecretKey"                       = (Get-OrCreate "jwt-$Environment" 48)
    "Seed__SuperAdminEmail"                = $AdminEmail
    "Email__Host"                          = $SmtpHost
    "Email__Port"                          = "$SmtpPort"
    "Email__Username"                      = $SmtpUsername
    "Email__FromAddress"                   = $SmtpFromAddress
    "Email__FromName"                      = $SmtpFromName
    "Storage__Provider"                    = "AzureBlob"
    "BlobStorage__ConnectionString"   = $storageConnection
    "DataProtection__KeysPath"             = "/home/data-protection-keys"
    "DataProtection__AllowUnencryptedKeys" = "true"
    "ForwardedHeaders__TrustAllProxies"    = "true"
    "Webhooks__CuelinksToken"              = (Get-OrCreate "cuelinks-token-$Environment" 32)
    "Payouts__Provider"                    = "Manual"
}

$smtpKey = Get-Optional "brevo-smtp-key"
if ($smtpKey) { $settings["Email__Password"] = $smtpKey }
else { Write-Warning "No $SecretsDir\brevo-smtp-key.txt: the API will run but cannot send sign-up codes until it is added." }

$cuelinksKey = Get-Optional "cuelinks-api-key"
if ($cuelinksKey) { $settings["AffiliateNetworks__Cuelinks__ApiKey"] = $cuelinksKey }

$out = Join-Path $PSScriptRoot "$Environment.settings.json"
$settings | ConvertTo-Json | Set-Content -Path $out -Encoding utf8
Write-Host "Wrote $out ($($settings.Count) settings; git-ignored)." -ForegroundColor Green
