#!/usr/bin/env bash
# Install the Reacti git hooks into .git/hooks/.
# Run once, from anywhere inside the repo:
#   bash scripts/install-hooks.sh

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
src="$repo_root/scripts/git-hooks"
dst="$repo_root/.git/hooks"

mkdir -p "$dst"
for f in "$src"/*; do
  name=$(basename "$f")
  cp "$f" "$dst/$name"
  chmod +x "$dst/$name"
  echo "installed: $name"
done

echo
echo "Done. Try 'git commit' on main to test - it should be refused."
