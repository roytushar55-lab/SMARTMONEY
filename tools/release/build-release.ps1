<#
.SYNOPSIS
  Builds the Play Store bundles (.aab) for the user app and the admin app,
  pointed at the production API, and refuses to build anything that could
  not be uploaded.

.DESCRIPTION
  Checks before building, for each app:
    - the API address is https and not localhost / 10.0.2.2;
    - android/key.properties exists and its keystore file is present
      (otherwise Gradle silently signs with the debug key, which Play refuses);
    - the application ID is no longer the com.example template.
  Then runs flutter test and flutter build appbundle --release.

  Needs the Flutter SDK and the Android SDK (ANDROID_HOME) on this machine.

.EXAMPLE
  tools\release\build-release.ps1 -ApiBaseUrl https://api.smart-money.in
  tools\release\build-release.ps1 -ApiBaseUrl https://api.smart-money.in -Apps mobile
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ApiBaseUrl,
    [ValidateSet("mobile", "admin")] [string[]] $Apps = @("mobile", "admin"),
    [switch] $SkipTests
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$folders = @{ mobile = "smart_money_mobile"; admin = "admin" }

$uri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne "https") {
    throw "ApiBaseUrl must be an absolute https URL, got '$ApiBaseUrl'. Android release builds refuse plain http."
}
if ($uri.Host -in @("localhost", "127.0.0.1", "10.0.2.2", "::1")) {
    throw "ApiBaseUrl points at a development host ($($uri.Host)). Use the production API address."
}
$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw "flutter is not on PATH." }
if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
    Write-Warning "ANDROID_HOME is not set. If 'flutter doctor' cannot find the Android SDK the build will fail."
}

# Check everything first, so a problem in the second app does not surface
# after a ten-minute build of the first.
foreach ($app in $Apps) {
    $dir = Join-Path $repo $folders[$app]
    $keyProps = Join-Path $dir "android\key.properties"
    if (-not (Test-Path $keyProps)) {
        throw "[$app] $keyProps is missing. Create the upload keystore and key.properties first (see the SmartMoney Go-Live Plan)."
    }
    $props = @{}
    foreach ($line in Get-Content $keyProps) {
        if ($line -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $props[$Matches[1]] = $Matches[2].Trim() }
    }
    foreach ($k in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        if (-not $props[$k]) { throw "[$app] key.properties has no '$k'." }
    }
    # Gradle resolves storeFile against the android/ folder (rootProject.file).
    $store = $props["storeFile"]
    if (-not [IO.Path]::IsPathRooted($store)) { $store = Join-Path $dir "android\$store" }
    if (-not (Test-Path $store)) { throw "[$app] keystore not found at $store." }

    $gradle = Get-Content (Join-Path $dir "android\app\build.gradle.kts") -Raw
    if ($gradle -match 'applicationId\s*=\s*"com\.example\.') {
        throw "[$app] applicationId is still the com.example template. Set the approved app ID first; Play rejects com.example."
    }
}

$outputs = @()
foreach ($app in $Apps) {
    $dir = Join-Path $repo $folders[$app]
    Write-Host "`n=== $app ($($folders[$app])) ===" -ForegroundColor Cyan
    Push-Location $dir
    try {
        if (-not $SkipTests) {
            Write-Host "flutter test ..."
            & flutter test
            if ($LASTEXITCODE -ne 0) { throw "[$app] tests failed; not building." }
        }
        Write-Host "flutter build appbundle --release (API $ApiBaseUrl) ..."
        & flutter build appbundle --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw "[$app] build failed." }
        $aab = Join-Path $dir "build\app\outputs\bundle\release\app-release.aab"
        if (-not (Test-Path $aab)) { throw "[$app] build reported success but $aab is missing." }
        $outputs += [pscustomobject]@{ App = $app; Bundle = $aab; SizeMB = [math]::Round((Get-Item $aab).Length / 1MB, 1) }
    }
    finally {
        Pop-Location
    }
}

Write-Host "`nBundles ready to upload in Play Console:" -ForegroundColor Green
$outputs | Format-Table -AutoSize
Write-Host "User app: Testing > Internal testing. Admin app: Testing > Closed testing, admin emails only."
Write-Host "Bump the +N in each pubspec.yaml version before the next upload; Play rejects a repeated versionCode."
