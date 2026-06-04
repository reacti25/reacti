# Third round of CI fix-ups onto feature/test-environment.
$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'feature/test-environment') {
    git switch feature/test-environment
}

git add .github/workflows/backend-ci.yml .github/workflows/flutter-ci.yml scripts/push-ci-fixups-3.ps1

if (-not (git diff --cached --name-only)) {
    Write-Host "Nothing to commit."
    exit 0
}

git commit -m "ci: drop --parallel for tests, bump Flutter to 3.36 for Dart 3.10

Backend:
- 'php artisan test --parallel' requires brianium/paratest which isn't a
  project dep. Removed --parallel; sequential is fine for our test count.

Flutter:
- 3.35.x ships Dart 3.9.2 which is still below the 3.10.0 floor needed by
  flutter_local_notifications ^21. Bumped to 3.36.x (Dart 3.10).
"

git push
Write-Host "Pushed."
