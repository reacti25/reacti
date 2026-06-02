# Commit and push the test-environment work.
#
# Run after first-push.ps1 has succeeded. From C:\Users\Achia\reacti:
#   .\scripts\push-test-environment.ps1

$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

# Make sure we're not on main.
$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'develop') {
    Write-Host "Switching to develop first."
    git switch develop
}

# Cut feature branch
$branch = 'feature/test-environment'
$exists = git branch --list $branch
if ($exists) {
    Write-Host "Branch '$branch' already exists, switching to it."
    git switch $branch
} else {
    git switch -c $branch
}

# Install local pre-commit hook (one-time, but safe to re-run)
Write-Host "==> installing git hooks"
.\scripts\install-hooks.ps1

# Stage everything new under the relevant paths
git add scripts/git-hooks scripts/install-hooks.ps1 scripts/install-hooks.sh
git add backend/phpunit.xml
git add backend/database/factories/UserFactory.php
git add backend/tests/Feature/Patent backend/tests/Feature/Auth backend/tests/Feature/Friends
git add app/test
git add scripts/push-test-environment.ps1

# Confirm there's something to commit
$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Host "Nothing to commit. Is the work already pushed?"
    exit 0
}
Write-Host "==> staged:"
$staged | ForEach-Object { Write-Host "    $_" }

git commit -m "feat(test): wire test environments and patent-flow regression test

Backend:
- phpunit.xml uses SQLite in-memory, sync queue, array cache, mail, broadcast=null,
  and ships a placeholder JWT_SECRET so 'php artisan test' runs from a fresh clone.
- UserFactory rewritten to match the real users table (first_name, last_name,
  username, email, phone, role, status, otp_verified_at).
- tests/Feature/Patent/ReactionFlowTest.php asserts the full patent loop:
  send media as 'normal' (server stores is_blurred=true) -> mark-viewed
  (server flips is_blurred=false, is_viewed=true) -> upload reaction
  (message_type=reaction, reply_to_id chains it) -> conversation contains both.
- Light auth + friend-request feature tests scaffolded.

App:
- widget_test.dart no longer references MyApp (which boots Firebase / DI and
  cannot run in 'flutter test').
- networks/endpoints_test.dart pins the URLs the client expects so a
  rename on the backend forces both sides to move together.

Tooling:
- scripts/git-hooks/pre-commit refuses direct commits to main/master.
- scripts/install-hooks.ps1 / .sh install it.
"

Write-Host "==> push"
git push -u origin $branch

Write-Host ""
Write-Host "DONE. Open a PR:"
Write-Host "  https://github.com/reacti25/reacti/compare/develop...$branch"
