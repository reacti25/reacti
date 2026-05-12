# Install the Reacti git hooks into .git/hooks/.
#
# Run once, from anywhere inside the repo:
#   .\scripts\install-hooks.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Error "Not inside a git repository."
    exit 1
}

$src = Join-Path $repoRoot 'scripts\git-hooks'
$dst = Join-Path $repoRoot '.git\hooks'

if (-not (Test-Path $src)) {
    Write-Error "Hooks source dir not found: $src"
    exit 1
}

New-Item -ItemType Directory -Force -Path $dst | Out-Null

Get-ChildItem -Path $src -File | ForEach-Object {
    $target = Join-Path $dst $_.Name
    Copy-Item -Path $_.FullName -Destination $target -Force
    # On Windows, Git for Windows runs hooks via bash.exe and respects the shebang.
    # No chmod needed; just ensure the file isn't blocked.
    Unblock-File -Path $target -ErrorAction SilentlyContinue
    Write-Host "installed: $($_.Name)"
}

Write-Host ""
Write-Host "Done. Try 'git commit' on main to test - it should be refused."
