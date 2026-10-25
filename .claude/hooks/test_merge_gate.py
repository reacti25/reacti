"""Every way of merging a PR must reach the gate. Run: python .claude/hooks/test_merge_gate.py"""
from merge_gate import pr_to_check

CASES = {
    "gh pr merge 510 --squash": "510",
    "gh pr merge --squash 510": "510",
    "cd /c/x && gh pr merge 510": "510",
    "gh pr merge https://github.com/reacti25/reacti/pull/510": "510",
    "gh pr merge --squash": "",  # current branch's PR
    "gh pr merge": "",
    "gh api -X PUT repos/reacti25/reacti/pulls/510/merge": "510",
    "gh pr merge --auto --squash 7 && echo done": "7",
    "gh pr merge $P --squash 2>&1 | tail -1": "?",  # variable: refuse, don't read the 2 of 2>&1
    "gh pr merge --squash 2>&1": "",
    "gh pr merge 515 --squash 2>&1 | tail -1; echo x": "515",
    "gh api -X PUT repos/o/r/pulls/$N/merge": "?",
    "ls": None,
    "gh pr view 510": None,
    "gh pr checks 510 | grep merge": None,
}

for cmd, want in CASES.items():
    got = pr_to_check(cmd)
    assert got == want, f"{cmd!r}: got {got!r}, want {want!r}"
print(f"ok, {len(CASES)} cases")
