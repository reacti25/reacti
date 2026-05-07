# Fifth round: case-sensitivity fix for the import path.
$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Achia\reacti'

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'feature/test-environment') {
    git switch feature/test-environment
}

git add app/lib/helpers/all_routes.dart scripts/push-ci-fixups-5.ps1

if (-not (git diff --cached --name-only)) {
    Write-Host "Nothing to commit."
    exit 0
}

git commit -m "fix(app): correct case in add_member_screen import

lib/helpers/all_routes.dart imported '../features/group_member/presentation/add_member_Screen.dart'
(uppercase S) but the file on disk is 'add_member_screen.dart' (lowercase).
Worked on the agency's Mac/Windows machines (case-insensitive filesystems);
breaks Linux CI. Fixed the import path.
"

git push
Write-Host "Pushed."
