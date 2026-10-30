"""Every way of merging a PR must reach the gate. Run: python .claude/hooks/test_merge_gate.py"""
from merge_gate import lab_passed, missing_boxes, pr_to_check, refused_write

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
PATENT = "## Affects the patent flow?\n\n- [x] No\n- [ ] Yes\n\n## Gate\n\n"
TWO = PATENT + "- [x] Ponytail pass\nPonytail notes: cut one helper\n- [x] Releasable"
APPROVED = TWO + "\n- [x] Achia approved merging into develop"
STAGED = TWO + "\n- [x] Staging confirmed by Achia: build 1186"
BOXES = {
    (TWO, "develop"): ["Achia approved merging into develop"],  # rule 6: Achia opens develop
    (APPROVED, "develop"): [],
    (TWO, "feature/e2e-test-server"): [],  # branch into branch: no approval needed
    (TWO, "main"): ["Staging confirmed by Achia"],  # main feeds prod: staging first
    (STAGED, "main"): [],
    (STAGED.replace("[x] Staging", "[ ] Staging"), "main"): ["Staging confirmed by Achia"],
    # A ticked box without notes, or the template's blank, is not a pass.
    (TWO.replace("cut one helper", ""), "feature/x"): ["Ponytail notes"],
    (TWO.replace("cut one helper", "____ (what"), "feature/x"): ["Ponytail notes"],
    # No patent answer: the ticks further down must not count for it.
    (TWO.replace("[x] No", "[ ] No"), "feature/x"): ["Patent flow answer"],
    (PATENT.replace("[x] No", "[ ] No").replace("[ ] Yes", "[x] Yes") + TWO[len(PATENT):], "feature/x"): [],
    ("", "develop"): ["Patent flow answer", "Ponytail pass", "Ponytail notes", "Releasable",
                      "Achia approved merging into develop"],
    (None, "main"): ["Patent flow answer", "Ponytail pass", "Ponytail notes", "Releasable",
                     "Staging confirmed by Achia"],
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
# True = refused.
WRITES = {
    "git push origin develop": True,
    "git -c credential.helper= push origin HEAD:develop": True,
    "git push origin feature/x": False,
    "git push origin fix/develop-notes": False,
    "git push -u origin chore/approval-rule": False,
    "gh workflow run ios-testflight.yml --ref feature/e2e-test-server": True,
    "gh workflow run ios-testflight.yml": True,  # default ref is not develop
    "gh workflow run 'iOS Staging to TestFlight' -r fix/x": True,
    "gh workflow run ios-testflight.yml --ref develop": False,
    "gh api -X POST repos/o/r/actions/workflows/ios-testflight.yml/dispatches -f ref=fix/x": True,
    "gh api -X POST repos/o/r/actions/workflows/ios-testflight.yml/dispatches -f ref=develop": False,
    "gh workflow run testing-lab.yml --ref feature/x": False,
    "git log origin/develop": False,
}
for cmd, want in WRITES.items():
    got = refused_write(cmd) is not None
    assert got == want, f"{cmd!r}: refused {got}, want {want}"
print(f"ok, {len(CASES) + len(BOXES) + len(LAB) + len(WRITES)} cases")
