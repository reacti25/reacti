#!/usr/bin/env bash
# Invite links on a real Android system (plan Step 8), with BOTH apps already
# installed: asks Android which apps can open each host's invite link, and
# fails unless each link resolves to its own app and never to the other.
#
# This checks the apps' link claims (intent filters). Whether Android has
# *verified* them against /.well-known/assetlinks.json depends on the server
# being deployed, so that state is printed for information, not enforced.
#
# Usage (emulator running, both APKs installed): android_app_links.sh
set -uo pipefail

failed=0

# Prints the packages Android offers for opening $1 from a browser.
handlers() {
  adb shell cmd package query-activities --brief \
    -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "$1" \
    | tr -d '\r' | grep -o 'com\.reacti\.app[a-z.]*' | sort -u | tr '\n' ' '
}

check() { # url expected-package
  local got
  got=$(handlers "$1")
  if [ "$got" = "$2 " ]; then
    echo "$1 -> $2"
  else
    echo "::error::$1 should open only $2, but Android offers: ${got:-nothing}"
    failed=1
  fi
}

check "https://reacti.io/i/abc123" com.reacti.app
check "https://staging.reacti.io/i/abc123" com.reacti.app.staging

for pkg in com.reacti.app com.reacti.app.staging; do
  echo "--- verification state for $pkg (informational) ---"
  adb shell pm get-app-links "$pkg" | tr -d '\r' || true
done
exit "$failed"
