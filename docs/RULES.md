# Reacti rules map

Every rule Claude works by, in one place, with what enforces it. Approved by
Achia on 2026-10-30. Shown at the start of every Claude session (a
SessionStart hook in the user settings reads this file from `origin/develop`).

**Rule 0: every rule is mandatory.** A rule is skipped only with Achia's
explicit yes in the conversation, asked for that one case, naming the rule.
"It is only a small change" is not an exception.

Enforced by: 🟢 a machine blocks it · 🟡 partly · 📝 written only (Claude must
keep it; the session-start map keeps it in view).

## A. Branches and releases

| # | Rule | Enforced by |
|---|------|-------------|
| 1 | All work on branches. Nothing into develop without Achia's yes for that change. | 🟢 merge gate (develop box, no push to develop) + GitHub ruleset on develop (PR only, no direct push) |
| 2 | The testing lab passes on the branch before any merge. | 🟡 merge gate checks the "Testing lab" result once the lab is on develop; then a required check |
| 3 | Staging app builds only from develop, one per approved batch, after Achia's yes. | 🟢 merge gate (refuses any other ref) + 📝 the yes |
| 4 | develop is releasable now; long work lives on its own branch. Ask "this ships with the next release. OK?" before the first develop merge. | 🟢 "Releasable" box |
| 5 | Multi-step work stays on one branch until all of it works. | 📝 |
| 6 | Nothing reaches production until Achia confirmed it on a named staging build. | 🟢 "Staging confirmed" box into main + GitHub approval on prod deploys |
| 7 | Only develop merges into main. | 🟢 "Source must be develop" check |
| 8 | App first: the new app is live before the server deploy. | 📝 (prod deploy approval is manual) |
| 9 | No production deploy or server access unless Achia says so. | 🟢 deploys (GitHub approval) · 📝 server access |
| 10 | AWS stays on its own branch until the credits arrive. | 📝 |

## B. Code quality

| # | Rule | Enforced by |
|---|------|-------------|
| 11 | Ponytail pass over the branch diff before every merge, with notes on what it found. | 🟢 merge gate ("Ponytail pass" box + "Ponytail notes:" line) |
| 12 | Every code part documented, single-purpose, the why commented. | 📝 |
| 13 | Tests for every code part; the required checks are green. | 🟢 PHP Tests + Analyze & Test + coverage floors |
| 14 | Formatting and analysis clean (dart format, flutter analyze, pint). | 🟢 CI |
| 15 | A change to the reaction-recording flow comes with an end-to-end test; every PR answers the question. | 🟢 merge gate (one answer ticked) + 📝 the test |
| 16 | Load the clean-code-standards skill before the first change. | 📝 |
| 17 | No long dashes in anything the user reads. | 🟢 `app/test/no_em_dashes_test.dart` |
| 18 | Never weaken TLS. | 🟢 `app/test/no_tls_override_test.dart` |

## C. Secrets and safety

| # | Rule | Enforced by |
|---|------|-------------|
| 19 | Never commit secrets (`.local-secrets/`, a real `.env`, key JSON, tokens). | 🟢 .gitignore + "Secret scan" required check |
| 20 | Never ask Achia to paste a secret. | 📝 |
| 21 | Never install or download anything on Achia's PC without asking. | 📝 + permission prompts |
| 22 | Never take a Hostinger snapshot over the only rollback point. | 📝 |

## D. Working with Achia

| # | Rule | Enforced by |
|---|------|-------------|
| 23 | Run commands myself; never hand Achia lines to paste. | 📝 |
| 24 | Short answers when Achia asks for short. | 📝 |
| 25 | Skipping any rule needs Achia's explicit yes for that case (rule 0). | 📝 |

## Where the machines live

* Merge gate: `.claude/hooks/merge_gate.py` (self-test `test_merge_gate.py`),
  loaded from `origin/develop` by a PreToolUse hook on Bash and PowerShell in
  `~/.claude/settings.json`. Fails closed.
* GitHub: classic protection + ruleset on develop, ruleset `protect-main` on
  main, `production` environment reviewers.
* CI: `backend-ci.yml`, `flutter-ci.yml`, `secret-scan.yml`,
  `testing-lab.yml`, `enforce-main-source-branch.yml`.
