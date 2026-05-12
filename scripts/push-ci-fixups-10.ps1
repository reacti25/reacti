# Tenth round: switch to actingAs() for auth, drop @test in favor of #[Test].
$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'feature/test-environment') {
    git switch feature/test-environment
}

git add backend/tests/Feature scripts/push-ci-fixups-10.ps1

if (-not (git diff --cached --name-only)) {
    Write-Host "Nothing to commit."
    exit 0
}

git commit -m "test(backend): use actingAs() for auth, switch to #[Test] attribute

Auth approach:
- Manually setting the Authorization header across multiple requests in a
  single test left auth state from the previous request stuck on the
  shared application instance, so Bob's mark-viewed call was being
  evaluated as Alice (or no user) - which is why the chat lookup missed
  even though the row clearly had receiver_id=Bob in the DB.
- Switched all three steps of the patent flow to actingAs(\$user, 'api')
  which sets the user explicitly per request and bypasses the header
  parsing entirely.
- Same change applied to FriendRequestTest.

Test metadata:
- Replaced /** @test */ doc-comments with the #[Test] attribute. PHPUnit
  was warning about doc-comment metadata being removed in PHPUnit 12.
"

git push
Write-Host "Pushed."
