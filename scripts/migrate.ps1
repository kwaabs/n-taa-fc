param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Network,
    [Parameter(Mandatory = $true)][string]$DatabaseUrl,
    [Parameter(Mandatory = $true)][ValidateSet("up", "down", "version")][string]$Action
)

$ErrorActionPreference = "Stop"

# Same git PATH scrub as compose.ps1 — docker CLI may still probe git.
$env:PATH = (
    $env:PATH -split ';' |
    Where-Object { $_ -and ($_ -notmatch '(?i)[\\/]git[\\/]bin') -and ($_ -notmatch '(?i)laragon[\\/]bin[\\/]git') }
) -join ';'

$env:DOCKER_BUILDKIT = "0"
$env:BUILDX_GIT_LABELS = "0"

$migrations = Join-Path $Root "services\fc-api\migrations"
# Docker Desktop/Rancher on Windows prefers forward slashes in -v
$migrationsDocker = ($migrations -replace '\\', '/')

$migrateArgs = @(
    "run", "--rm",
    "--network", $Network,
    "-v", "${migrationsDocker}:/migrations:ro",
    "migrate/migrate:v4.18.1",
    "-path", "/migrations",
    "-database", $DatabaseUrl
)

switch ($Action) {
    "up" { $migrateArgs += "up" }
    "down" { $migrateArgs += @("down", "-all") }
    "version" { $migrateArgs += "version" }
}

& docker @migrateArgs
exit $LASTEXITCODE
