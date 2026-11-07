#!/usr/bin/env bash
# Self-check of lab_scope.sh: fails if a change would skip a phone it needs.
set -uo pipefail
scope="$(dirname "$0")/lab_scope.sh"

# Asserts the phones chosen for the paths in $2 are $1 ("android iphone").
expect() {
  local got
  got=$(printf "$2" | bash "$scope" | cut -d= -f2 | xargs)
  [ "$got" = "$1" ] || { echo "FAIL: '$2' gave '$got', wanted '$1'"; exit 1; }
}

expect 'true true' ''                                  # no list: fail safe
expect 'false false' 'docs/a.pdf\nREADME.md\n'
expect 'true false' 'backend/app/A.php\ndocs/a.md\n'
expect 'true true' 'backend/app/A.php\napp/lib/a.dart\n'
expect 'true true' 'app/lib/a.dart\n'
expect 'true true' '.github/workflows/testing-lab.yml\n'
expect 'true true' 'docs/a.md\n.github/scripts/ios_e2e.sh\n'
expect 'true true' 'backend.txt\n'                     # not the backend folder
echo "lab_scope ok"
