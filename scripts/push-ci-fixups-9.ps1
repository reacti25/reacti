# Ninth round: debug the mark-viewed step.
$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'feature/test-environment') {
    git switch feature/test-environment
}

git add backend/tests/Feature/Patent/ReactionFlowTest.php scripts/push-ci-fixups-9.ps1

if (-not (git diff --cached --name-only)) {
    Write-Host "Nothing to commit."
    exit 0
}

git commit -m "test(backend): dump mark-viewed response when assertion fails

Step 1 of the patent flow now passes (is_blurred=true confirmed).
Step 2 hits the mark-viewed controller's 'Message not found' branch,
which means either auth resolves the wrong user or the chat lookup
misses. Adding a STDERR dump so the next CI run shows the actual
response body and the chat row in the DB at that moment.
"

git push
Write-Host "Pushed."
