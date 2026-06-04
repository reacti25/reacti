# Progress — app-hardening master plan

Status board for `docs/MASTER-PLAN-app-hardening-2026-06-04.md`, kept current
by Claude Code so Achia and the operator can see at a glance what has landed on
`develop`, what is next, and where a `develop`→`main` promotion makes sense.

**Convention:** every line item is a small PR off `develop`. ✅ = merged to
`develop`. 🔄 = in progress / PR open. ⬜ = not started. ⛔ = parked on a
decision gate (see `NEEDS-ACHIA.md`).

_Last updated: 2026-06-04._

---

## Stage 0 — CI gates + test machinery (EP0)

Largely completed by earlier work (PRs up to #119 + dependabot/dashboard
commits). Verified present on `develop`:

- ✅ Both required checks always report (no `paths:` filter on `backend-ci.yml`
  / `flutter-ci.yml`).
- ✅ PHPStan/Larastan with baseline (`backend/phpstan.neon` +
  `phpstan-baseline.neon`); gate fails only on *new* violations.
- ✅ `dart format --set-exit-if-changed` + `flutter analyze` gates.
- ✅ Native build jobs: Android debug + iOS no-codesign (non-required, observed).
- ✅ Coverage reporting on both pipelines (no floor yet — floor comes in Stage 1).
- ✅ `composer audit` job (non-required; surfaces deferred CVE-2026-48019).
- ✅ Dependabot (`.github/dependabot.yml`: composer / npm / pub / actions).
- ✅ `deploy-dashboard.yml` points at `develop`.
- 🔄 Mop-up: fold the non-fatal `|| true` ssh-keyscan fix into
  `prod-deploy-check.yml` + `staging-deploy.yml` (match `backend-deploy.yml`).
- ⛔ Switch CI `composer update`→`composer install` — blocked on **DG8**
  (need the original `composer.json`). See `NEEDS-ACHIA.md`.

## Stage 4a — security criticals, exploitable today (EP1) — pulled forward

Highest real-world risk; being done right after the Stage 0 mop-up.

- ⬜ Delete the unauthenticated `routes/web.php` maintenance routes
  (`/run-migrate-fresh` can drop the DB).
- ⬜ Rate-limit auth/OTP routes + OTP attempt counter.
- ⬜ Stop returning OTP codes in API response bodies.
- ⬜ Remove the `MyHttpOverrides` TLS bypass in `app/lib/main.dart`.
- ⬜ Move auth token to secure storage; erase it on logout.

## Stage 1 — test net / patent-flow harness

- ⬜ Patent-flow integration harness (Inbox/GroupInbox full loop). **Prereq for
  any patent-code change (Stage 4d).**
- ⬜ Backend service unit tests; broaden feature tests on risky routes.
- ⬜ App `rx_*` + screen widget tests.
- ⬜ Set + ratchet a coverage floor.

## Stage 2 — documentation

- ⬜ Dartdoc / PHPDoc everywhere; `docs/architecture.md`; API spec;
  README/LICENSE/CONTRIBUTING.

## Stage 3 — safe refactor leftovers (mostly done already)

- ⬜ `achiar_expert_app`→`reacti` rename; safe dead-code deletion; prune deps.

## Stage 4b–4k — functional hardening

See the master plan. Sequenced after 4a + Stage 1.

## Stage 5 — features

- ⬜ Only after the above.

---

## Promotion checkpoints (for Achia)

The master plan calls for a TestFlight check + `develop`→`main` promotion after
**4a** and again after **4c**. This file will call those out explicitly when the
work reaches them. No promotion has been requested yet under this plan.
