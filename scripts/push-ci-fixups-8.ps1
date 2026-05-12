# Eighth round: fix the actual tests against the real controller shapes.
$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'feature/test-environment') {
    git switch feature/test-environment
}

git add backend/tests/Feature scripts/push-ci-fixups-8.ps1

if (-not (git diff --cached --name-only)) {
    Write-Host "Nothing to commit."
    exit 0
}

git commit -m "test(backend): align tests with real controller behavior

ReactionFlowTest:
- postJson() does not support multipart, so the file was never uploaded
  and the controller saw \$file = null, which kept is_blurred = false.
  Switched to post() with the file inlined in the data array and the
  Authorization Bearer header passed via the third argument.
- SQLite stores booleans as 0/1; assertDatabaseHas now uses 0/1 literals.

LoginTest:
- AuthenticationController returns the JWT under data.token, not
  data.access_token.
- 'password' field has min:8 validation, so 'wrong' would have hit the
  422 validator before reaching the auth check. Use a long wrong
  password to actually exercise the credential check (-> 401).
- Assert success=true and data.token, matching the ApiResponse trait shape.
- Make sure the test user has otp_verified_at set or login refuses with
  'Please verify your email before logging in.'

FriendRequestTest:
- Bearer header passed via postJson()'s third (headers) argument.
- Assert success=true.
"

git push
Write-Host "Pushed."
