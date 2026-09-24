<#
.SYNOPSIS
  Build a signed Android release APK and upload it to RustFS public/releases/.

.DESCRIPTION
  1. Reads version from mobile/pubspec.yaml (bump it yourself before releasing)
  2. flutter build apk --release
  3. Uploads versioned APK + latest.apk + manifest.json to RustFS

  One-time signing setup (from mobile/android/):
    keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fieldcollector
    copy keystore.properties.example keystore.properties
    # edit keystore.properties with store/key passwords

.PARAMETER Force
  Overwrite an existing object for the same versionCode.

.PARAMETER SkipBuild
  Re-upload an APK already at mobile/build/app/outputs/flutter-apk/app-release.apk

.PARAMETER DryRun
  Build (unless SkipBuild) and print actions without uploading.

.PARAMETER EnvFile
  Path to env file with S3_* vars (default: services/fc-api/.env, else root .env)
#>
param(
    [switch]$Force,
    [switch]$SkipBuild,
    [switch]$DryRun,
    [string]$EnvFile = ""
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Mobile = Join-Path $Root "mobile"
$AndroidDir = Join-Path $Mobile "android"
$KeystoreProps = Join-Path $AndroidDir "keystore.properties"
$ApkPath = Join-Path $Mobile "build\app\outputs\flutter-apk\app-release.apk"
$Pubspec = Join-Path $Mobile "pubspec.yaml"
$ObjectPrefix = "public/releases/android"

function Read-DotEnv([string]$Path) {
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $i = $line.IndexOf("=")
        if ($i -lt 1) { return }
        $k = $line.Substring(0, $i).Trim()
        $v = $line.Substring($i + 1).Trim()
        if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        $map[$k] = $v
    }
    return $map
}

function Get-PubspecVersion([string]$Path) {
    $raw = Get-Content $Path -Raw
    if ($raw -notmatch '(?m)^version:\s*([^\s#]+)') {
        throw "Could not parse version from $Path"
    }
    $full = $Matches[1].Trim()
    if ($full -notmatch '^([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)$') {
        throw "pubspec version must look like 0.1.0+1 (got '$full')"
    }
    return @{
        Full        = $full
        VersionName = $Matches[1]
        VersionCode = [int]$Matches[2]
    }
}

Write-Host "=== Field Collector mobile release ==="

if (-not (Test-Path $KeystoreProps)) {
    Write-Host @"

Missing $KeystoreProps

One-time setup (from mobile/android):
  keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fieldcollector
  copy keystore.properties.example keystore.properties
  # fill storePassword / keyPassword

"@
    exit 1
}

$ver = Get-PubspecVersion $Pubspec
Write-Host "Version: $($ver.VersionName)+$($ver.VersionCode)"

if (-not $EnvFile) {
    $candidate = Join-Path $Root "services\fc-api\.env"
    if (-not (Test-Path $candidate)) { $candidate = Join-Path $Root ".env" }
    $EnvFile = $candidate
}
$envMap = Read-DotEnv $EnvFile
$S3Endpoint = if ($envMap["S3_ENDPOINT"]) { $envMap["S3_ENDPOINT"] } else { "http://localhost:5352" }
$S3Public = if ($envMap["S3_PUBLIC_ENDPOINT"]) { $envMap["S3_PUBLIC_ENDPOINT"] } else { $S3Endpoint }
$S3Bucket = if ($envMap["S3_BUCKET"]) { $envMap["S3_BUCKET"] } else { "field-collector" }
$S3Access = if ($envMap["S3_ACCESS_KEY"]) { $envMap["S3_ACCESS_KEY"] } else { "rustfsadmin" }
$S3Secret = if ($envMap["S3_SECRET_KEY"]) { $envMap["S3_SECRET_KEY"] } else { "rustfsadmin" }

$S3Endpoint = $S3Endpoint.TrimEnd("/")
$S3Public = $S3Public.TrimEnd("/")

$versionedKey = "$ObjectPrefix/$($ver.VersionName)+$($ver.VersionCode).apk"
$latestKey = "$ObjectPrefix/latest.apk"
$manifestKey = "$ObjectPrefix/manifest.json"
$downloadUrl = "$S3Public/$S3Bucket/$latestKey"

if (-not $SkipBuild) {
    Write-Host "Building release APK..."
    Push-Location $Mobile
    try {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
        & flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk --release failed" }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "SkipBuild: using existing APK"
}

if (-not (Test-Path $ApkPath)) {
    throw "APK not found at $ApkPath"
}

$apkItem = Get-Item $ApkPath
$hash = (Get-FileHash -Path $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "APK: $($apkItem.FullName)"
Write-Host "Size: $($apkItem.Length) bytes"
Write-Host "SHA256: $hash"

$releasedAt = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$manifest = @{
    platform    = "android"
    versionName = $ver.VersionName
    versionCode = $ver.VersionCode
    sha256      = $hash
    sizeBytes   = $apkItem.Length
    releasedAt  = $releasedAt
    downloadUrl = $downloadUrl
} | ConvertTo-Json -Compress

$manifestPath = Join-Path $env:TEMP "fc-android-manifest-$($ver.VersionCode).json"
[System.IO.File]::WriteAllText($manifestPath, $manifest, [System.Text.UTF8Encoding]::new($false))

if ($DryRun) {
    Write-Host "DryRun — would upload:"
    Write-Host "  $versionedKey"
    Write-Host "  $latestKey"
    Write-Host "  $manifestKey"
    Write-Host "  downloadUrl: $downloadUrl"
    exit 0
}

# Host gateway so containers can reach RustFS published on the host
$mcEndpoint = $S3Endpoint -replace "localhost", "host.docker.internal" -replace "127\.0\.0\.1", "host.docker.internal"

Write-Host "Uploading to $S3Bucket via minio/mc ($mcEndpoint)..."

$apkLinux = ($apkItem.FullName -replace '\\', '/')
# Docker Desktop on Windows: convert C:\... → /c/...
if ($apkLinux -match '^([A-Za-z]):/(.*)$') {
    $apkLinux = "/$($Matches[1].ToLower())/$($Matches[2])"
}
$manifestLinux = ($manifestPath -replace '\\', '/')
if ($manifestLinux -match '^([A-Za-z]):/(.*)$') {
    $manifestLinux = "/$($Matches[1].ToLower())/$($Matches[2])"
}

$mcOverwrite = if ($Force) { "1" } else { "0" }

$mcScript = @'
set -e
mc alias set local "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY"
VERSIONED_KEY="$OBJECT_PREFIX/${VERSION_NAME}+${VERSION_CODE}.apk"
LATEST_KEY="$OBJECT_PREFIX/latest.apk"
MANIFEST_KEY="$OBJECT_PREFIX/manifest.json"
if mc stat "local/$S3_BUCKET/$VERSIONED_KEY" >/dev/null 2>&1; then
  if [ "$FORCE" != "1" ]; then
    echo "ERROR: $VERSIONED_KEY already exists. Bump pubspec versionCode or pass -Force."
    exit 2
  fi
fi
mc cp --overwrite /apk/app-release.apk "local/$S3_BUCKET/$VERSIONED_KEY"
mc cp --overwrite /apk/app-release.apk "local/$S3_BUCKET/$LATEST_KEY"
mc cp --overwrite /manifest/manifest.json "local/$S3_BUCKET/$MANIFEST_KEY"
echo UPLOAD_OK
'@

$mcScriptPath = Join-Path $env:TEMP "fc-mobile-release-mc.sh"
$mcScript = $mcScript -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($mcScriptPath, $mcScript)

$scriptLinux = ($mcScriptPath -replace '\\', '/')
if ($scriptLinux -match '^([A-Za-z]):/(.*)$') {
    $scriptLinux = "/$($Matches[1].ToLower())/$($Matches[2])"
}

& docker run --rm `
    -e "FORCE=$mcOverwrite" `
    -e "S3_ENDPOINT=$mcEndpoint" `
    -e "S3_ACCESS_KEY=$S3Access" `
    -e "S3_SECRET_KEY=$S3Secret" `
    -e "S3_BUCKET=$S3Bucket" `
    -e "OBJECT_PREFIX=$ObjectPrefix" `
    -e "VERSION_NAME=$($ver.VersionName)" `
    -e "VERSION_CODE=$($ver.VersionCode)" `
    -v "${apkLinux}:/apk/app-release.apk:ro" `
    -v "${manifestLinux}:/manifest/manifest.json:ro" `
    -v "${scriptLinux}:/run.sh:ro" `
    --add-host=host.docker.internal:host-gateway `
    minio/mc:latest `
    /bin/sh /run.sh

if ($LASTEXITCODE -ne 0) {
    throw "Upload failed (exit $LASTEXITCODE). Is RustFS up at $S3Endpoint?"
}

Write-Host ""
Write-Host "Release published."
Write-Host "  versioned: $S3Public/$S3Bucket/$versionedKey"
Write-Host "  latest:    $downloadUrl"
Write-Host "  manifest:  $S3Public/$S3Bucket/$manifestKey"
Write-Host "  API:       GET /api/v1/app/android/latest"
