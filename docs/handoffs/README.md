# Handoffs & decision archive

Historical, point-in-time documents from earlier Cowork/Claude Code sessions:
session handoffs, status snapshots, resolved decision gates, and superseded
plans. They are kept for provenance and incident forensics — **they are not
live instructions.**

For what is *currently* true, read these instead:

- `../../CLAUDE.md` — entry point and guardrails.
- `../../PROGRESS.md` — live status board (what's landed on `develop`, what's next).
- `../../NEEDS-ACHIA.md` — open product/legal/business decision gates.
- `../conventions.md` — how the code looks.
- `../../.claude/skills/clean-code-standards/SKILL.md` — the consolidated
  engineering + operational playbook (the durable lessons from the files below
  have been folded into it).

## What's here

| File | What it is |
|---|---|
| `HANDOFF-deploy-2026-05-24.md` | Post-mortem of the 2026-05-23 prod incident (backend-shape divergence broke the live app). The origin of the staging+testing initiative. |
| `HANDOFF-status-2026-05-29.md` | Full status snapshot: prod≠main, empty staging DB, deploy-path uncertainty. |
| `HANDOFF-private-chat-bug-2026-05-30.md` | The private-chat "black screen" bug investigation (the `is_viewed` int-vs-dynamic shape bug). |
| `HANDOFF-execute-master-plan-2026-06-04.md` | Handoff to execute the app-hardening master plan. |
| `HANDOFF-promotion-2026-06-04.md` | `develop`→`main` promotion handoff + deploy-key setup notes. |
| `OPERATOR-STATUS-2026-06-04.md` | Operator note: prod deploy freeze (app-first rule) + run-continuously cadence. |
| `DECISIONS-gates-resolved-2026-06-08.md` | Achia's resolutions of decision gates DG1–DG9. |
| `PLAN-phase5-staging-on-device-2026-05-29.md` | Superseded plan (TestFlight staging on device). |
| `PLAN-baseline-reset-and-phased-rebuild-2026-05-30.md` | Superseded plan (baseline reset). |

The current active plan is `../MASTER-PLAN-app-hardening-2026-06-04.md` and the
testing/staging design in `../PLAN-staging-and-testing-2026-05-24.md`.
