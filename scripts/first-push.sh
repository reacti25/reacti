#!/usr/bin/env bash
# =============================================================================
# Reacti — first push to GitHub (Git Bash / WSL version)
# Run from inside the repo folder. Mirrors first-push.ps1.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

if ! grep -q 'Reacti on GitHub.txt' .gitignore; then
  echo "ABORT: .gitignore is missing 'Reacti on GitHub.txt'." >&2
  exit 1
fi

echo "==> git init"
git init -b main
git config user.name 'Reacti'
git config user.email 'Reacti.ai25@gmail.com'

echo "==> add remote"
git remote add origin 'https://github.com/reacti25/reacti.git'

echo "==> stage"
git add -A

echo "==> sanity check"
LEAKS=$(git ls-files --cached | grep -E '^archives/|^\.local-secrets/|^backend/\.env$|^backend/node_modules/|Reacti on GitHub\.txt' || true)
if [ -n "$LEAKS" ]; then
  echo "ABORT: forbidden paths staged:" >&2
  echo "$LEAKS" >&2
  exit 1
fi
echo "    OK"

echo "==> initial commit"
git commit -m "chore: import production source v1.0.9

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
inside recordVideoSilently()."

echo "==> push main"
git push -u origin main

echo "==> cut and push develop"
git switch -c develop
git push -u origin develop

echo
echo "DONE. Both branches pushed."
