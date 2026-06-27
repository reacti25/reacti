# Plan — Ponytail refactor campaign (2026-06-17)

**Skill:** `ponytail` (DietrichGebert) — "the best code is the code you never wrote."
**Executor:** Claude Code · **Owner/approver:** Achia

Goal: incrementally simplify Reacti with ponytail, **one safe branch at a time**,
each with a clear **value report** (what / why / profit), through the standard
pipeline: `branch → tests green → develop → staging → main/prod (app-first)`.

## Guardrails (non-negotiable)

- **Achia-driven — propose, then approve.** Claude Code **proposes** candidates with
  a value report and **pauses**; it does **not** refactor anything Achia hasn't
  greenlit (her standing rule). One concern per branch/PR.
- **Behavior-preserving.** Refactors must not change user-facing behavior. Proven by
  tests. (This is cleanup, not feature work.)
- **Patent path protected.** Anything touching the send→record→reaction flow,
  the blur/unblur transition, `mark-viewed`, the reaction upload, or the broadcast
  events requires the **full patent-flow harness green + explicit extra approval**.
  Start with **non-patent** areas.
- **Tests gate everything.** Full suite + patent harness green before a branch
  leaves; required checks **"Analyze & Test"** / **"PHP Tests"** green.
- **Lazy, not negligent.** Never weaken input validation, trust-boundary checks,
  data-loss handling, security, or accessibility — even to delete code. (Ponytail
  itself respects this; enforce it.)
- **Staging-first + app-first.** App changes verified on a staging TestFlight build
  before main/prod; release new app first, then backend.

## Per-branch workflow (the pipeline you described)

1. **Propose** — Claude Code analyses a contained area and proposes a refactor + the
   value report. *Analysis only, no changes.*
2. **Approve** — Achia reads the value report (sees the profit/reason) and approves
   or skips.
3. **Refactor** — Claude Code cuts `refactor/ponytail-<area>` off `develop`, applies
   ponytail's ladder to that area, runs `/ponytail-review` to catch more, keeps it
   behavior-preserving.
4. **Prove** — full tests + patent harness green, locally and in CI.
5. **PR → develop** — with the value report in the description; Achia reviews; merge.
6. **Staging** — TestFlight build for app changes; Achia signs off.
7. **Release** — batched into the next `develop→main` promotion + release, app-first,
   per `docs/RUNBOOK-first-production-release-2026-06-12.md`.

## Value report — required in every refactor PR

So you always know *why* and *what's the profit*:

- **What** — the exact code simplified/removed (files, **before→after line counts**).
- **Why** — which ponytail rung applied (didn't need to exist / stdlib / native /
  existing dependency / one line) and what the old complexity was costing.
- **Profit** — measurable: lines removed, dependencies dropped, fewer states/branches,
  clearer logic; any perf/size impact if relevant.
- **Safety** — which tests cover this code; confirmation behavior is unchanged;
  patent-harness status if the path is anywhere near it.
- **Risk** — honest note on anything to watch. Rollback = revert the single PR.

## Candidate tiers (do in this order)

- **Tier 1 — start here (lowest risk, clearest wins):** dead/unused code, redundant
  wrapper classes, over-built `Manager`/`Helper`/`Utils` with static-only methods,
  one-line replacements (a native/stdlib feature vs a hand-rolled one), unused
  dependencies — all in **non-patent, well-tested** files.
- **Tier 2:** simplify verbose logic / de-duplicate in feature code (still
  non-patent).
- **Tier 3 — careful, later:** networking / auth / shared infrastructure — full
  review, more tests.
- **Off-limits without explicit OK + full harness:** the patent surface
  (`app/lib/features/chat/.../receiver_message_widget.dart` blur/record/reaction,
  `mark-viewed`, send/reaction upload, `backend/app/Events/`).

This complements the existing `docs/refactor/` convention-convergence plan —
ponytail trims code *within* those targets rather than replacing them.

## Kickoff for Claude Code

```
Read .claude/skills/clean-code-standards/SKILL.md and
docs/PLAN-ponytail-refactor-2026-06-17.md. Start a ponytail refactor campaign —
ANALYSIS FIRST, no changes yet.

Using ponytail, scan the codebase and PROPOSE the first 3 SAFE, contained, Tier-1
candidates (dead code, redundant wrappers, over-built Manager/Helper/Utils,
one-line/native replacements, unused deps) in NON-patent, well-tested areas. For
EACH, give the value report: What (files + before→after line counts), Why (which
ponytail rung + what the complexity costs), Profit (lines/deps/complexity removed),
Safety (tests covering it; behavior unchanged), Risk.

Do NOT touch the patent path (receiver_message_widget.dart blur/record/reaction,
mark-viewed, send/reaction upload, backend/app/Events). Make NO changes — just the 3
proposals + value reports — and PAUSE for Achia to pick which to do.

When she approves one: branch refactor/ponytail-<area> off develop, apply it
(behavior-preserving), run /ponytail-review to catch more, full tests + patent
harness green, open a PR to develop with the value report. One concern per PR.
Don't promote to main, deploy, or touch the App Store. Staging-first for app
changes.
```
