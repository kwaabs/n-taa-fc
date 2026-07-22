# Copies .env.example -> .env for root and app/service dirs when .env is missing.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

$pairs = @(
    @{ Dir = $Root; Name = "root" },
    @{ Dir = Join-Path $Root "services\fc-api"; Name = "fc-api" },
    @{ Dir = Join-Path $Root "services\geo-api"; Name = "geo-api" },
    @{ Dir = Join-Path $Root "apps\fc-web"; Name = "fc-web" },
    @{ Dir = Join-Path $Root "apps\geo-web"; Name = "geo-web" }
)

foreach ($p in $pairs) {
    $example = Join-Path $p.Dir ".env.example"
    $envFile = Join-Path $p.Dir ".env"
    if (-not (Test-Path $example)) {
        Write-Host "skip $($p.Name): no .env.example"
        continue
    }
    if (Test-Path $envFile) {
        Write-Host "ok   $($p.Name): .env already exists"
        continue
    }
    Copy-Item -Path $example -Destination $envFile
    Write-Host "created $($p.Name): .env from .env.example"
}
