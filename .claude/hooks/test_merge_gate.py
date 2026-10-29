"""Every way of merging a PR must reach the gate. Run: python .claude/hooks/test_merge_gate.py"""
from merge_gate import lab_passed, missing_boxes, pr_to_check

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
TWO = "- [x] Ponytail pass\n- [x] Releasable"
STAGED = TWO + "\n- [x] Staging confirmed by Achia: build 1186"
BOXES = {
    (TWO, "develop"): [],
    (TWO, "main"): ["Staging confirmed by Achia"],  # main feeds prod: staging first
    (STAGED, "main"): [],
    (STAGED.replace("[x] Staging", "[ ] Staging"), "main"): ["Staging confirmed by Achia"],
    ("", "develop"): ["Ponytail pass", "Releasable"],
    (None, "main"): ["Ponytail pass", "Releasable", "Staging confirmed by Achia"],
}
for (body, base), want in BOXES.items():
    got = missing_boxes(body, base)
    assert got == want, f"{base} {body!r}: got {got!r}, want {want!r}"
LAB = {
    "passed": ([{"name": "Testing lab", "conclusion": "SUCCESS"}], True),
    "failed": ([{"name": "Testing lab", "conclusion": "FAILURE"}], False),
    "still running": ([{"name": "Testing lab", "conclusion": ""}], False),
    "never ran": ([{"name": "PHP Tests", "conclusion": "SUCCESS"}], False),
    "no checks": (None, False),
}
for case, (checks, want) in LAB.items():
    assert lab_passed(checks) == want, f"lab {case}: want {want}"
print(f"ok, {len(CASES) + len(BOXES) + len(LAB)} cases")
