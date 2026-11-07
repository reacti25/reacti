#!/usr/bin/env bash
# Testing lab: which phones a change needs. Reads the changed paths on stdin
# and prints "android=true|false" and "iphone=true|false" for GITHUB_OUTPUT.
#
#   * Only documents: no phone, nothing a phone runs changed.
#   * Only backend/: Android alone. The journeys still prove the server against
#     the real app, on the phone that costs a tenth of a Mac and takes a third
#     of the time; the API the two phones call is the same.
#   * Anything else, or no list at all (fails safe): both phones.
#
# Usage: gh pr diff "$PR" --name-only | lab_scope.sh
# Check: lab_scope_check.sh
set -uo pipefail

files=$(cat)
code=$(printf '%s\n' "$files" | grep -vE '^(docs|reports|research_notes)/|\.md$')
client=$(printf '%s\n' "$code" | grep -v '^backend/')

android=true
iphone=true
if [ -n "$files" ]; then
  [ -n "$client" ] || iphone=false
  [ -n "$code" ] || android=false
fi
echo "android=$android"
echo "iphone=$iphone"
