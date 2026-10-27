"""Claude Code PreToolUse hook: refuse `gh pr merge` until the PR description
shows the checks Claude kept skipping (retros 2026-10-25 and 2026-10-27).

  - [x] Ponytail pass ...   (clean-code-standards skill, section 6)
  - [x] Releasable ...      (develop must always be shippable to prod)
  - [x] Staging confirmed by Achia ...   (PRs into main only: staging first)

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
# Golden rule (2026-10-27): main feeds the production deploy, so a promotion
# also needs Achia's own confirmation on a staging build, not "it deployed".
REQUIRED_INTO_MAIN = {
    "Staging confirmed by Achia": r"- \[[xX]\] Staging confirmed by Achia",
}


def missing_boxes(body: str, base: str) -> list[str]:
    """Names of the Gate boxes this PR body has not ticked for its base branch."""
    required = REQUIRED | (REQUIRED_INTO_MAIN if base == "main" else {})
    return [name for name, pattern in required.items() if not re.search(pattern, body or "")]


def pr_to_check(command: str) -> str | None:
    """The PR a command merges, "" for the current branch's PR, None if it
    merges nothing. Covers every form seen: number before or after flags,
    a PR URL, no argument at all, and the REST merge endpoint via gh api.
    An argument it cannot resolve (a shell variable like $P) returns "?",
    which main() refuses: the gate must know which PR it is checking."""
    api = re.search(r"pulls/(\S+)/merge", command)
    if api:
        return api.group(1) if api.group(1).isdigit() else "?"
    m = re.search(r"gh\s+pr\s+merge\b(.*)", command)
    if not m:
        return None
    for tok in m.group(1).split():
        if tok[0] in ";&|":
            break
        if tok.startswith("-") or re.match(r"\d*[<>]", tok):  # flags, redirections like 2>&1
            continue
        num = re.search(r"(?:/pull/)?(\d+)$", tok)
        return num.group(1) if num else "?"
    return ""


def main() -> int:
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    pr = pr_to_check(command)
    if pr is None:
        return 0
    if pr == "?":
        print("merge gate: write the PR number literally (not a variable) so the gate can check it.", file=sys.stderr)
        return 2
    out = subprocess.run(["gh", "pr", "view", *([pr] if pr else []), "--json", "number,body,baseRefName"],
                         capture_output=True, text=True, encoding="utf-8", timeout=30)  # Windows default is cp1255
    if out.returncode != 0:
        print(f"merge gate: could not read PR #{pr}: {out.stderr.strip()}", file=sys.stderr)
        return 2
    data = json.loads(out.stdout)
    pr = data["number"]
    missing = missing_boxes(data.get("body"), data.get("baseRefName"))
    if not missing:
        return 0
    print(f"merge gate: PR #{pr} into {data.get('baseRefName')} is missing ticked boxes: {', '.join(missing)}. "
          "Do the ponytail pass over the diff and confirm it is releasable to prod NOW; into main, Achia must "
          "also have confirmed it on a staging build (name the build). Then tick the boxes in the PR "
          "description (see .github/pull_request_template.md).", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
