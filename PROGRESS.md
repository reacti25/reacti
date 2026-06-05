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

Highest real-world risk; done right after the Stage 0 mop-up. An audit found
items 1–4 were already fixed and tested on `develop` by earlier work; this
initiative closed the remaining token item.

- ✅ Delete the unauthenticated `routes/web.php` maintenance routes
  (`/run-migrate-fresh` can drop the DB). *(already on `develop`; pinned by
  `MaintenanceRoutesRemovedTest`.)*
- ✅ Rate-limit auth/OTP routes (`throttle:` on login/register/OTP). *(already on
  `develop`; pinned by `AuthRateLimitTest`.)*
- ✅ Stop returning OTP codes in API response bodies. *(already on `develop`;
  pinned by `OtpNotInResponseTest`.)*
- ✅ Remove the `MyHttpOverrides` TLS bypass in `app/lib/main.dart`. *(already on
  `develop`; pinned by `no_tls_override_test`.)*
- ✅ Erase the session on logout — `totalDataClean()` on the **success** path
  (was only on the 401 path). PR #124.
- ✅ Move the auth token to `flutter_secure_storage` (`AuthTokenStore`,
  secure-at-rest + synchronous in-memory mirror). PR #125.

### ✅ CHECKPOINT — Stage 4a complete (ready for Achia)

Stage 4a (EP1 exploitable-now security criticals) is **complete and green on
`develop`/staging.** Per the handoff cadence, work is **paused here** for your
test + promotion before the next big step (Stage 1 — the patent-flow harness).

**What changed (security):** logout now fully clears the session; the auth
bearer token is stored encrypted in the platform secure store (Keychain /
Keystore) instead of the plaintext GetStorage file. The other 4a criticals
(maintenance routes, OTP rate-limiting, OTP-not-in-response, TLS-bypass removal)
were already on `develop` and are each pinned by a regression test.

**This step changed Flutter/app code** (logout, token storage, Dio header, chat
init, login/signup) — so you need a **fresh staging TestFlight build** to test it
on your iPhone. Backend was unchanged by the app-side PRs.

**What to test on the Staging app (TestFlight):**
1. Log in → use the app (chat list, open a conversation) → confirm everything
   still works (the token now comes from secure storage).
2. Log out → confirm you land on the login screen and a subsequent app action
   requires logging in again (no lingering session).
3. Log in again → kill and reopen the app → confirm you stay logged in (the
   token persists across restarts from secure storage).
4. Sign up a new account through OTP verification → confirm you end up logged in.

**Then:** if it looks good, this is a natural point to promote `develop`→`main`.
Tell me to continue and I'll start Stage 1 (the patent-flow integration
harness). The remaining 4b–4k hardening and Stage 1 are **not** started.

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
