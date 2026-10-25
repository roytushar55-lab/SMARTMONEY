<#
.SYNOPSIS
  One-time setup that lets the GitHub "Deploy API" workflow deploy to the
  App Service with OpenID Connect, so no Azure password or publish profile
  is stored in GitHub.

.DESCRIPTION
  Creates (or reuses) a Microsoft Entra app registration and its service
  principal, trusts GitHub tokens from exactly one repository and one GitHub
  environment ("production"), and gives it the "Website Contributor" role on
  the one web app only. Re-running it is safe.

  Run after deploy-api.ps1 has created the web app, signed in with an account
  that can create app registrations and assign roles (the subscription owner).

.EXAMPLE
  .\setup-github-oidc.ps1 -Repository rupankar/smartmoney `
      -ResourceGroup smartmoney-prod -WebAppName smartmoney-api-st01
#>
[CmdletBinding()]
param(
    # "owner/name" of the client's GitHub repository, exactly as on github.com.
    [Parameter(Mandatory)] [ValidatePattern('^[^/\s]+/[^/\s]+$')] [string] $Repository,
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $WebAppName,
    [string] $Environment = "production",
    [string] $AppRegistrationName = "smartmoney-github-deploy"
)

$ErrorActionPreference = "Stop"

function Invoke-Az {
    $output = & az @args
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') failed (exit $LASTEXITCODE)" }
    return $output
}

# Windows PowerShell 5.1 turns redirected native stderr into a terminating
# error under Stop, so quiet lookups run with Continue locally.
function Get-AzQuiet {
    $ErrorActionPreference = "Continue"
    $output = & az @args --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $output
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw "Azure CLI (az) is not installed." }
$accountJson = Get-AzQuiet account show
if (-not $accountJson) { throw "Not signed in. Run: az login" }
$account = ($accountJson -join "`n") | ConvertFrom-Json

$webAppId = Get-AzQuiet webapp show --resource-group $ResourceGroup --name $WebAppName --query id --output tsv
if (-not $webAppId) {
    throw "Web app '$WebAppName' not found in '$ResourceGroup'. Run deploy-api.ps1 first."
}

# 1. App registration + service principal
$appId = Get-AzQuiet ad app list --display-name $AppRegistrationName --query "[0].appId" --output tsv
if (-not $appId) {
    Write-Host "Creating app registration $AppRegistrationName..."
    $appId = Invoke-Az ad app create --display-name $AppRegistrationName --query appId --output tsv
} else {
    Write-Host "App registration $AppRegistrationName exists ($appId)."
}

if (-not (Get-AzQuiet ad sp show --id $appId --query id --output tsv)) {
    Write-Host "Creating service principal..."
    Invoke-Az ad sp create --id $appId --output none | Out-Null
}

# 2. Trust GitHub tokens from this repository's production environment only.
$subject = "repo:${Repository}:environment:${Environment}"
$credentialName = "github-" + ($Repository -replace '[^A-Za-z0-9-]', '-') + "-" + $Environment
$existing = Get-AzQuiet ad app federated-credential list --id $appId --query "[?subject=='$subject'] | length(@)" --output tsv
if ($existing -and [int]$existing -gt 0) {
    Write-Host "Federated credential for $subject exists."
} else {
    Write-Host "Adding federated credential for $subject..."
    $tmp = New-TemporaryFile
    try {
        @{
            name      = $credentialName.Substring(0, [Math]::Min(120, $credentialName.Length))
            issuer    = "https://token.actions.githubusercontent.com"
            subject   = $subject
            audiences = @("api://AzureADTokenExchange")
        } | ConvertTo-Json | Set-Content -Path $tmp -Encoding utf8
        Invoke-Az ad app federated-credential create --id $appId --parameters "@$tmp" --output none | Out-Null
    }
    finally {
        Remove-Item $tmp -Force
    }
}

# 3. Least privilege: deploy rights on this one web app.
$hasRole = Get-AzQuiet role assignment list --assignee $appId --scope $webAppId --role "Website Contributor" --query "length(@)" --output tsv
if ($hasRole -and [int]$hasRole -gt 0) {
    Write-Host "Role 'Website Contributor' already assigned on $WebAppName."
} else {
    Write-Host "Assigning 'Website Contributor' on $WebAppName (can take a minute to apply)..."
    Invoke-Az role assignment create --assignee $appId --role "Website Contributor" --scope $webAppId --output none | Out-Null
}

Write-Host ""
Write-Host "Done. In GitHub ($Repository): Settings > Environments > New environment '$Environment'" -ForegroundColor Green
Write-Host "(optionally add yourself as a required reviewer), then Settings > Secrets and variables > Actions > Variables:" -ForegroundColor Green
Write-Host "  AZURE_CLIENT_ID        = $appId"
Write-Host "  AZURE_TENANT_ID        = $($account.tenantId)"
Write-Host "  AZURE_SUBSCRIPTION_ID  = $($account.id)"
Write-Host "  AZURE_WEBAPP_NAME      = $WebAppName"
Write-Host "  API_HEALTH_URL         = https://api.smart-money.in/health   (once the domain is connected)"
Write-Host ""
Write-Host "These are identifiers, not secrets: the trust is limited to $subject."
