# Second round of CI fix-ups onto feature/test-environment.
$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'feature/test-environment') {
    git switch feature/test-environment
}

git add .github/workflows/backend-ci.yml .github/workflows/flutter-ci.yml scripts/push-ci-fixups-2.ps1

$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Host "Nothing to commit."
    exit 0
}

git commit -m "ci: drop key:generate, fix APP_KEY, bump Flutter for Dart 3.10

Backend:
- key:generate needs a .env file we don't commit; removed the step.
- The previous APP_KEY placeholder was not actually 32 bytes when base64
  decoded, which would have broken Laravel's encrypter once tests started.
  Replaced with a real 32-byte placeholder key.

Flutter:
- flutter_local_notifications ^21.0.0 requires Dart ^3.10. Flutter 3.32.x
  ships Dart 3.8.x. Bumped FLUTTER_VERSION to 3.35.x (Dart 3.10).
"

git push
Write-Host "Pushed."
