# Fourth round of CI fix-ups onto feature/test-environment.
$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'feature/test-environment') {
    git switch feature/test-environment
}

git add .github/workflows/flutter-ci.yml scripts/push-ci-fixups-4.ps1

if (-not (git diff --cached --name-only)) {
    Write-Host "Nothing to commit."
    exit 0
}

git commit -m "ci: bump Flutter to 3.41.x to match the agency's lockfile

pubspec.lock pins Flutter >= 3.41.0 (Dart >= 3.11.0). My earlier guesses
of 3.27 / 3.32 / 3.35 / 3.36 were all below that floor.
"

git push
Write-Host "Pushed."
