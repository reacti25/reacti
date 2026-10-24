"""Claude Code PreToolUse hook: refuse `gh pr merge` until the PR description
shows the two checks Claude kept skipping (retro 2026-10-25).

  - [x] Ponytail pass ...   (clean-code-standards skill, section 6)
  - [x] Releasable ...      (develop must always be shippable to prod)

Reads the hook payload on stdin. Exit 2 blocks the command and shows stderr
to Claude; exit 0 lets it through. Anything that is not a PR merge passes.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys

REQUIRED = {
    "Ponytail pass": r"- \[[xX]\] Ponytail pass",
    "Releasable": r"- \[[xX]\] Releasable",
}


def pr_to_check(command: str) -> str | None:
    """The PR a command merges, "" for the current branch's PR, None if it
    merges nothing. Covers every form seen: number before or after flags,
    a PR URL, no argument at all, and the REST merge endpoint via gh api."""
    api = re.search(r"pulls/(\d+)/merge", command)
    if api:
        return api.group(1)
    m = re.search(r"gh\s+pr\s+merge\b([^;&|]*)", command)
    if not m:
        return None
    arg = re.search(r"(?:/pull/|\s)(\d+)\b", m.group(1))
    return arg.group(1) if arg else ""


def main() -> int:
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    pr = pr_to_check(command)
    if pr is None:
        return 0
    out = subprocess.run(["gh", "pr", "view", *([pr] if pr else []), "--json", "number,body,baseRefName"],
                         capture_output=True, text=True, encoding="utf-8", timeout=30)  # Windows default is cp1255
    if out.returncode != 0:
        print(f"merge gate: could not read PR #{pr}: {out.stderr.strip()}", file=sys.stderr)
        return 2
    data = json.loads(out.stdout)
    pr = data["number"]
    missing = [name for name, pattern in REQUIRED.items() if not re.search(pattern, data.get("body") or "")]
    if not missing:
        return 0
    print(f"merge gate: PR #{pr} into {data.get('baseRefName')} is missing ticked boxes: {', '.join(missing)}. "
          "Do the ponytail pass over the diff and confirm it is releasable to prod NOW, "
          "then tick both boxes in the PR description (see .github/pull_request_template.md).", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
