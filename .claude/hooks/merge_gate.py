"""Claude Code PreToolUse hook: refuse `gh pr merge` until the PR description
shows the checks Claude kept skipping (retros 2026-10-25 and 2026-10-27).

  - [x] No / Yes ...        (Affects the patent flow? one answer ticked)
  - [x] Ponytail pass ...   (clean-code-standards skill, section 6)
  Ponytail notes: ...       (what the pass found or cut: proof it was done)
  - [x] Releasable ...      (develop must always be shippable to prod)
  - [x] Achia approved merging into develop ...   (PRs into develop only)
  - [x] Staging confirmed by Achia ...   (PRs into main only: staging first)

It also refuses a direct push to develop and a staging app build from any
ref but develop (golden rule 6, 2026-10-30: branches and the testing lab
first, develop and the staging app only when Achia says so).

Reads the hook payload on stdin. Exit 2 blocks the command and shows stderr
to Claude; exit 0 lets it through. Anything else passes.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys

# Rules map (docs/RULES.md, 2026-10-30): a tick alone once passed for a
# ponytail pass never done, so the notes must say what it found.
REQUIRED = {
    "Patent flow answer": r"## Affects the patent flow\?[^#]*- \[[xX]\]",
    "Ponytail pass": r"- \[[xX]\] Ponytail pass",
    "Ponytail notes": r"Ponytail notes:[ \t]*[^\s_]",
    "Releasable": r"- \[[xX]\] Releasable",
}
# Golden rule (2026-10-27): main feeds the production deploy, so a promotion
# also needs Achia's own confirmation on a staging build, not "it deployed".
REQUIRED_INTO_MAIN = {
    "Staging confirmed by Achia": r"- \[[xX]\] Staging confirmed by Achia",
}
# Golden rule 6 (2026-10-30): develop ships with the next release, so only
# Achia opens it, once the change is green in the testing lab on its branch.
REQUIRED_INTO_DEVELOP = {
    "Achia approved merging into develop": r"- \[[xX]\] Achia approved merging into develop",
}
STAGING_BUILD = re.compile(r"gh\s+workflow\s+run\b.*(ios-testflight|Staging to TestFlight)|workflows/ios-testflight\.yml/dispatches")
DEVELOP = r"(?<![\w/.-])develop(?![\w/.-])"


def missing_boxes(body: str, base: str) -> list[str]:
    """Names of the Gate boxes this PR body has not ticked for its base branch."""
    required = REQUIRED | {"main": REQUIRED_INTO_MAIN, "develop": REQUIRED_INTO_DEVELOP}.get(base, {})
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


def refused_write(command: str) -> str | None:
    """Why [command] may not run (a push to develop, or a staging app build
    that is not from develop), or None. Achia's yes still comes first for a
    develop staging build; the hook only stops the branch builds."""
    if re.search(r"\bgit\b.*\bpush\b.*(:|\s)" + DEVELOP, command):
        return "never push to develop; open a PR from a branch, green in the testing lab, and ask Achia."
    if STAGING_BUILD.search(command) and not re.search(r"(--ref|-r|ref=)[\s=]*" + DEVELOP, command):
        return "a staging app build runs only from develop (--ref develop), after Achia approved the batch."
    return None


def main() -> int:
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    refused = refused_write(command)
    if refused:
        print(f"merge gate: {refused}", file=sys.stderr)
        return 2
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
          "Do the ponytail pass over the diff and confirm it is releasable to prod NOW; into develop, Achia "
          "must have said yes after the lab passed on the branch; into main, Achia must "
          "also have confirmed it on a staging build (name the build). Then tick the boxes in the PR "
          "description (see .github/pull_request_template.md).", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
