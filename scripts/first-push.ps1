# =============================================================================
# Reacti - first push to GitHub
#
# Run this ONCE from PowerShell, from inside C:\Users\Achia\reacti\
# It will:
#   1. Check that the credentials note is gitignored.
#   2. git init the repo with main as default branch.
#   3. Configure user.name / user.email.
#   4. Add the remote pointing at https://github.com/reacti25/reacti.git
#   5. Stage, commit, and push main.
#   6. Cut develop, push develop.
#
# Prerequisite: Git for Windows + you're signed in to GitHub
# (e.g., via GitHub CLI 'gh auth login' or Git Credential Manager).
# =============================================================================

$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

# Sanity: refuse to run if the credentials note isn't gitignored
$ignoreCheck = Get-Content .gitignore | Select-String 'Reacti on GitHub.txt'
if (-not $ignoreCheck) {
    Write-Error "ABORT: .gitignore is missing the entry for the credentials note. Refusing to push."
    exit 1
}

Write-Host "==> git init"
git init -b main
git config user.name 'Reacti'
git config user.email 'Reacti.ai25@gmail.com'

Write-Host "==> add remote"
git remote add origin 'https://github.com/reacti25/reacti.git'

Write-Host "==> stage"
git add -A

Write-Host "==> sanity-check what will be committed"
$leaks = git ls-files --cached | Select-String -Pattern '^archives/|^\.local-secrets/|^backend/\.env$|^backend/node_modules/|Reacti on GitHub\.txt'
if ($leaks) {
    Write-Error "ABORT: would have committed these forbidden paths:`n$leaks"
    exit 1
}
Write-Host "    OK - leak check passed."

Write-Host "==> initial commit"
$commitMsg = @'
chore: import production source v1.0.9

Faithful import of the iOS-shipping Reacti app delivered by the original
development agency on 2026-04-30.

Layout:
- app/      Flutter mobile client
- backend/  Laravel 11 REST API with JWT auth and Pusher broadcasting
- docs/     Original product vision PDFs and iOS Simulator screenshots

backend/composer.json was reconstructed from composer.lock; the original
was missing from the delivery archive.

The patent-protected auto-record-reaction-on-message-open flow lives in
app/lib/features/chat/presentation/widget/receiver_message_widget.dart
inside recordVideoSilently().
'@
git commit -m $commitMsg

Write-Host "==> push main"
git push -u origin main

Write-Host "==> cut and push develop"
git switch -c develop
git push -u origin develop

Write-Host ""
Write-Host "DONE. Both branches pushed."
Write-Host "  main:    https://github.com/reacti25/reacti/tree/main"
Write-Host "  develop: https://github.com/reacti25/reacti/tree/develop"
Write-Host ""
Write-Host "Next step: turn on branch protection for main in the repo Settings."
