param(
    [Parameter(Mandatory = $true)][string]$ComposeFile,
    [Parameter(Mandatory = $true)][string]$ProjectDir,
    [Parameter(Mandatory = $true)][string]$EnvFile,
    [Parameter(Mandatory = $true)][string]$Args
)

$ErrorActionPreference = "Stop"

# Rancher/Docker on Windows often tries to shell out to git and fails with
# "error launching git: Access is denied" (Laragon git). Strip git dirs from PATH.
$env:PATH = (
    $env:PATH -split ';' |
    Where-Object { $_ -and ($_ -notmatch '(?i)[\\/]git[\\/]bin') -and ($_ -notmatch '(?i)laragon[\\/]bin[\\/]git') }
) -join ';'

$env:COMPOSE_BAKE = "false"
$env:DOCKER_BUILDKIT = "0"
$env:BUILDX_GIT_LABELS = "0"

$argList = $Args.Trim() -split '\s+'

& docker compose `
    -f $ComposeFile `
    --project-directory $ProjectDir `
    --env-file $EnvFile `
    @argList

exit $LASTEXITCODE
