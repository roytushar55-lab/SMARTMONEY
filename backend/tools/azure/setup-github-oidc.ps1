<#
.SYNOPSIS
  One-time setup that lets the GitHub "Deploy API" workflow deploy one
  target (UAT from the dev branch, or PROD from main) with OpenID Connect,
  so no Azure password is stored in GitHub. Run it once per target.

.DESCRIPTION
  Creates (or reuses) a Microsoft Entra app registration and its service
  principal, trusts GitHub tokens only from the given repository AND branch,
  and gives it the "Website Contributor" role on that one web app only.
  The UAT identity therefore cannot touch PROD, and nothing but a push to
  main can deploy PROD. Re-running it is safe.

  Needs rights to create app registrations and assign roles: run it in the
  Azure portal's Cloud Shell (PowerShell) as the subscription owner, after
  deploy-api.ps1 has created the web apps. Upload this file with Cloud
  Shell's "Manage files > Upload" first.

.EXAMPLE
  ./setup-github-oidc.ps1 -Repository smartmoneyindia/smart-money-app -Branch dev  -WebAppName smartmoney-api-uat
  ./setup-github-oidc.ps1 -Repository smartmoneyindia/smart-money-app -Branch main -WebAppName smartmoney-api-prod
#>
[CmdletBinding()]
param(
    # "owner/name" of the client's GitHub repository, exactly as on github.com.
    [Parameter(Mandatory)] [ValidatePattern('^[^/\s]+/[^/\s]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateSet("dev", "main")] [string] $Branch,
    [Parameter(Mandatory)] [string] $WebAppName,
    [string] $ResourceGroup = "smartmoney-rg",
    [string] $AppRegistrationName
)

$ErrorActionPreference = "Stop"
$target = if ($Branch -eq "main") { "PROD" } else { "UAT" }
if (-not $AppRegistrationName) { $AppRegistrationName = "smartmoney-github-deploy-$($target.ToLowerInvariant())" }

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

# 2. Trust GitHub tokens from this repository's branch only.
$subject = "repo:${Repository}:ref:refs/heads/${Branch}"
$credentialName = ("github-" + ($Repository -replace '[^A-Za-z0-9-]', '-') + "-" + $Branch)
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
Write-Host "Done ($target). Add these in GitHub ($Repository): Settings > Secrets and variables > Actions > Variables:" -ForegroundColor Green
Write-Host "  AZURE_TENANT_ID             = $($account.tenantId)"
Write-Host "  AZURE_SUBSCRIPTION_ID       = $($account.id)"
Write-Host "  AZURE_CLIENT_ID_$target       = $appId"
Write-Host "  AZURE_WEBAPP_NAME_$target     = $WebAppName"
Write-Host "  API_HEALTH_URL_$target        = https://$WebAppName.azurewebsites.net/health  (or the custom domain once connected)"
Write-Host ""
Write-Host "These are identifiers, not secrets: the trust is limited to $subject."
