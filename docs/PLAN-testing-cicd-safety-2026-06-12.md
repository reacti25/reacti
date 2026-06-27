# Plan — Testing, CI/CD & Safety hardening (2026-06-12)

**Author:** Cowork (operator session) · **Executor:** Claude Code · **Owner/approver:** Achia

This plan covers **only** three themes: **testing**, **CI/CD**, and
**safety/security**. It is scoped to what is *genuinely still open* as of
2026-06-12 — it does **not** re-list work already shipped. It supersedes nothing;
it complements `docs/MASTER-PLAN-app-hardening-2026-06-04.md` and
`docs/PLAN-staging-and-testing-2026-05-24.md` and fills the gaps those leave.

## How Claude Code should use this plan

- Read `.claude/skills/clean-code-standards/SKILL.md` first — its Part 2
  operational playbook (app-first release, prod≠main, decision gates, secrets
  hygiene, CI traps) governs everything below.
- Work the phases in order. Each **task** is one small, single-concern PR off
  `develop`, with tests, kept green on the required checks
  (**"PHP Tests"**, **"Analyze & Test"**). Conventional Commits.
- Do **not** start a new *phase* without telling Achia which phase you're in
  (per `CLAUDE.md`). Within a phase, flow through tasks without stopping.
- Anything marked **🔒 GATE** needs Achia (product/legal) or the operator
  (GitHub settings / prod) before it can land or take effect. Park it in
  `NEEDS-ACHIA.md`, keep moving on everything else.
- After each task, update `PROGRESS.md` (and the "Next release — what's in it"
  list when the change is user-facing).

## Guardrails that constrain every task here

- **App-first release ordering.** Nothing in this plan approves a production
  backend deploy. Merging `develop`→`main` is code-only; the prod Backend Deploy
  gate stays unapproved until the new iOS app is live (see SKILL.md).
- **Don't touch the prod server / CI→prod SSH** (Hostinger rate-block risk).
  Staging deploys from `develop` are fine.
- **Secrets** go through GitHub Actions secrets / `gh secret set`, never chat,
  never committed.

---

## Current state — already in place (do NOT rebuild)

So Claude Code doesn't duplicate finished work, the audit confirmed these exist
and are green/working on `develop`:

- Required checks **"PHP Tests"** (`backend-ci.yml`) and **"Analyze & Test"**
  (`flutter-ci.yml`), both filter-free, with coverage floors enforced
  (backend `--min=70`; app line floor ~35% via `flutter-ci.yml` lcov gate).
- PHPStan/Larastan with baseline; Pint format gate; `dart format` + analyze gate.
- `backend-ci.yml` **Dependency Audit** job (non-required) surfacing the deferred
  CVE-2026-48019.
- Test suites: `backend/tests/{Unit(8), Feature(47), Contract(4), Smoke(1)}`,
  `app/test/` (85 test files), incl. the patent-flow integration harness
  (InboxScreen + GroupInboxScreen).
- Workflows present: `contract-tests.yml`, `migration-tests.yml`,
  `post-deploy-smoke.yml` (9-step smoke), `staging-deploy.yml`,
  `prod-deploy-check.yml`, `backend-deploy.yml`, `ios-testflight.yml`,
  `ios-release.yml`, `enforce-main-source-branch.yml`, `deploy-dashboard.yml`.
- `.github/CODEOWNERS` guarding workflows, migrations, and the patent surface.
- The TLS bypass (`MyHttpOverrides`) is **already removed** from
  `app/lib/main.dart` (only a historical comment remains), pinned by
  `no_tls_override_test`.

---

# Phase A — Protect live users (highest priority)

The 2026-05-23 incident (a backend change the OLD live app couldn't read →
black chat screens) is the single worst failure mode. Phase A closes the gaps
that still leave the live app exposed to it, plus two concrete secret/config
leaks found in the audit.

## A1 — Backwards-compatibility test (staging-plan Layer 3g) — the keystone

**Why:** This is the one test that directly catches "new backend breaks the old
App Store app." It does not exist yet. Highest-value item in this plan.

**Branch:** `test/3g-backwards-compat`

**Steps:**
1. Pin the **currently-live App Store app version** as an annotated git tag
   (confirm the exact version with Achia — e.g. `app-live-vX.Y.Z`). The tag must
   point at the commit that produced the build now in the App Store, **not**
   `main`'s HEAD (prod≠main — verify the actual shipped commit first).
2. New workflow `.github/workflows/backwards-compat.yml`:
   - Triggers: `pull_request: [main]` and `push: [develop]`.
   - Checks out the pinned tag's `app/`, builds it, and runs its integration/
     contract assertions against the **develop/staging backend** (the candidate
     backend), using the `smoke-a` / `smoke-b` staging accounts.
   - Asserts the patent loop + core chat read/send still parse against the new
     backend's responses.
3. Make this a **required** status check on `main` once green (🔒 GATE —
   operator adds it to the `protect-main` ruleset).

**Acceptance:** A deliberate response-shape change to a core endpoint (e.g.
re-introduce the `is_viewed` int→bool change) makes this workflow **fail**.
Revert → green. Document the intentional-break test in the PR.

**Note:** if a full old-app build in CI proves too heavy, fall back to running
the **old app's contract fixtures** (the JSON shapes the live app expects)
against the new backend — same protection, cheaper. Decide in the PR and record
the trade-off.

## A2 — Move hardcoded Pusher/realtime credentials out of client code 🔒 (rotate)

**Why (audit finding):** `app/lib/features/chat/data/chat_realtime_service.dart`
hardcodes a realtime **host** (`climbiq-goonclimbers.com:8081`), an **app key**
(`d3d9ba606e9065ff0c3d1d566ccf904c`), and the `broadcasting/auth` URL. The host
doesn't even match `reacti.io`, and a committed key is a leaked credential.

**Branch:** `fix/realtime-config-from-define`

**Steps:**
1. Replace the hardcoded values with build-time config read via
   `String.fromEnvironment(...)` (mirror the `BASE_URL` pattern in
   `app/lib/networks/endpoints.dart`), e.g. `PUSHER_KEY`, `PUSHER_HOST`,
   `PUSHER_PORT`, `BROADCAST_AUTH_URL`, with production-safe defaults pointing at
   the real Reacti realtime host (confirm the correct prod host with Achia — the
   `climbiq-goonclimbers.com` value looks wrong/stale).
2. Pass them through `--dart-define` in `ios-testflight.yml` (staging) and
   `ios-release.yml` (prod), sourced from GitHub secrets.
3. **🔒 GATE / Achia:** treat the committed key as compromised — rotate the
   Pusher/Reverb credential after the new app ships (app-first; rotating before
   the old live app updates would break realtime on the live app). Park the
   rotation step in `NEEDS-ACHIA.md` tied to the next release.

**Acceptance:** No realtime secret or host literal remains in `app/lib/`
(grep clean); app builds against staging realtime via defines; a unit test
asserts the service reads config, not literals.

## A3 — Production-safe `.env.example` + config documentation

**Why (audit finding, backlog §11):** `backend/.env.example` ships
`APP_ENV=local`, `APP_DEBUG=true`, `LOG_LEVEL=debug`. A prod `.env` derived from
it leaks full Ignition stack traces.

**Branch:** `chore/env-example-prod-safe`

**Steps:**
1. Set `.env.example` to production-safe defaults: `APP_ENV=production`,
   `APP_DEBUG=false`, `LOG_LEVEL=error` (keep dev overrides documented inline).
2. Add `docs/configuration.md`: required vs optional env vars, and a short
   "deploying" checklist (debug off, key set, jwt secret set, CORS origins set).
3. No secrets in the file — only `.example` placeholders.

**Acceptance:** `.env.example` is safe to copy to prod as-is; `docs/configuration.md`
lists every env var the app boots with.

## A4 — Expand API contract tests to the full critical surface (Layer 3d completion)

**Why:** Contract tests are the per-endpoint shape lock that would have caught
the incident. Today only ~6 endpoints are covered (`POST /login`,
`GET /profile`, chat `list`, `conversation/{id}`, `mark-viewed/{id}`,
`send/{id}`). The endpoints the live app depends on most are still unlocked.

**Branch:** `test/3d-contract-expansion` (split into 2–3 PRs if large)

**Steps:** Add `backend/tests/Contract/` cases (reuse `ContractTestCase` +
`schemas/`) for at least: `POST /register`, `GET /user`, friends list +
`POST /friends/request`, groups list, `GET /groups/{id}/messages`, group send,
and **every patent-flow endpoint** (reaction send, group reaction, broadcast
payload shapes). Each test pins the exact JSON shape (keys + types) the live app
parses.

**Acceptance:** Each new endpoint has a contract test asserting key set + types;
a deliberate type change on any of them fails CI.

---

# Phase B — Close the test-wall gaps (staging-plan Layers 3e–3f) & app-side safety

## B1 — iOS integration tests in CI (Layer 3f) — does not exist yet

**Why:** No `app/integration_test/` and no iOS-integration workflow exist. This
is the app-side equivalent of the smoke test — it proves the real app drives the
real flows end-to-end.

**Branch:** `test/3f-ios-integration`

**Steps:**
1. Create `app/integration_test/` covering: login (smoke-a) → list chats →
   open private chat → send → receive; group send/receive; and the **patent
   loop** (open blurred media → record → reaction sent → unblur).
2. New `.github/workflows/ios-integration-test.yml` on `macos-15` (match
   existing macOS runner), pointed at staging via `--dart-define`. **Budget:**
   macOS minutes are ~10×; trigger only on `pull_request: [main]` and
   `push: [develop]`; keep runtime < 10 min.
3. Non-required at first (observe), promote to required on `main` once stable
   (🔒 GATE — operator).

**Acceptance:** The workflow boots a simulator and runs the flows green;
breaking the patent widget makes it fail.

## B2 — Strengthen the post-deploy smoke + make it gate staging health

**Why:** `post-deploy-smoke.yml` + `Smoke/SmokeTest.php` (9 steps) exist; ensure
it runs on **every** staging deploy via `workflow_run` and that a red smoke is
visible/blocking for promotion (not silently ignored).

**Branch:** `ci/smoke-after-staging-deploy`

**Steps:** Confirm/repair the `workflow_run` trigger chaining
`staging-deploy.yml` → smoke; surface failures on the commit status; document in
`docs/release-runbook.md` that a red post-deploy smoke blocks a promotion
recommendation. Add any missing assertion among the 9 steps (esp. the full
patent flow).

**Acceptance:** Merging to `develop` deploys staging then runs smoke; a forced
smoke failure shows red on the commit and is called out in the runbook.

## B3 — Whitelist the social-login provider param

**Why (audit, backlog §1 / R10):** `POST social/signin/{provider}`
(`backend/routes/api.php`) has no `in:google,apple` constraint → provider
injection. Social login is now wired+tested, so harden it (don't delete — see
DG2; confirm DG2 keep/remove with Achia before any deletion).

**Branch:** `fix/social-provider-whitelist`

**Steps:** Constrain the route param (`->whereIn('provider', ['google','apple'])`
or validate in the Form Request) and reject unknown providers with 422. Add a
Feature test for accepted + rejected providers.

**Acceptance:** `provider=evil` → 422 with a test pinning it.

## B4 — Scope the IDOR-adjacent `exists:` validation rules

**Why (audit, backlog §1):** unscoped existence checks let a user reference rows
in conversations/groups they aren't part of:
- `SingleChatController::send` `reply_to_id` (`exists:chats,id`) — scope to the
  current room.
- `GroupMessageController` `reply_to_message_id`
  (`exists:group_messages,id`) — scope to the group + verify membership.
- `forwardMessage` — verify the caller was party to the source message.
- `FindFriendController::findContacts` — replace interpolated `DB::raw("... {$user->id} ...")`
  with a binding; add `contacts` `array|max:1000`.

**Branch:** `fix/scoped-exists-rules` (one PR per controller is fine)

**Acceptance:** Feature tests prove a user cannot reply-to / forward / reference
a message or row outside their own rooms/groups (403/422); the raw SQL is
parameterized.

---

# Phase C — CI/CD hardening & coverage ratchet

## C1 — Admin-frontend (Vite/Tailwind) build job (backlog §11)

**Why:** `backend-ci.yml` never builds `backend`'s `vite build` assets, so a
broken Blade/Vite asset ships undetected.

**Branch:** `ci/backend-vite-build`

**Steps:** Add a job (or step) running `npm ci && npm run build` for the backend
front-end assets; fail on build error. Cache `node_modules`. Keep it a separate,
clearly-named check; decide required vs observed in the PR.

**Acceptance:** A deliberately broken asset import fails the job.

## C2 — Finish the ssh-keyscan mop-up (PROGRESS Stage 0 🔄)

**Why:** Fold the non-fatal `|| true` ssh-keyscan fix into
`prod-deploy-check.yml` + `staging-deploy.yml` to match `backend-deploy.yml`, so
a keyscan hiccup doesn't fail a deploy spuriously.

**Branch:** `ci/ssh-keyscan-nonfatal`

**Acceptance:** All three deploy workflows handle keyscan identically; staging
deploy unaffected. (Do not trigger a prod deploy to test — inspect the YAML.)

## C3 — Coverage-floor ratchet + first service-level unit tests

**Why:** Floors are "low by design." Ratchet them as coverage rises, and start
the true-DI service unit tests deferred to EP7.

**Branch:** `test/service-unit-and-ratchet`

**Steps:**
1. Add unit tests (no framework boot) for the highest-risk untested units the
   audit named: `ChatRealtimeService`, `VideoControllerCache` (LRU eviction +
   dispose), `NotificationService`, and the thin read endpoints (chat `room`,
   group `available-users`, group `messages/media`).
2. Once merged and coverage rises, **raise** the floors in `backend-ci.yml`
   (`--min`) and `flutter-ci.yml` (lcov floor) to just below the new actuals.
   Never lower a floor to pass.

**Acceptance:** New units covered; floors raised in the same or a follow-up PR
with the new numbers cited.

## C4 — Make the security/test layers required checks on `main` 🔒

**Why:** New layers only protect `main` once they're *required*. Several aren't.

**Branch:** operator/GitHub-settings task (not a code PR) — Claude Code documents
the exact list; the operator applies it in the `protect-main` ruleset.

**Steps:** Document in `docs/release-runbook.md` the full required-check set for
`main`: **"PHP Tests"**, **"Analyze & Test"**, contract-tests, migration-tests,
backwards-compat (A1), and iOS-integration (B1) once each is green. 🔒 GATE —
operator updates the ruleset; confirm both branch-protection systems (classic +
Rulesets) agree (SKILL.md CI trap).

**Acceptance:** Runbook lists the required set; operator confirms the ruleset
matches.

---

# Phase D — Deferred / gated (track, don't start without the gate)

These are real safety/CI items but each is blocked. Keep them visible in
`NEEDS-ACHIA.md`; do not start until the gate clears.

- **D1 — `composer update` → `composer install`** in `backend-ci.yml` (key cache
  on `composer.lock`, add `composer validate --strict`). 🔒 **GATE DG8** — needs
  the original `composer.json` from the dev/agency. Until then CI stays on
  `composer update`.
- **D2 — Trim `User::$fillable`** (remove `otp`, `otp_verified_at`,
  `reset_password_token`, `status`, `is_google_signin`, `google_id`). Needs care:
  registration/reset services mass-assign some of these — refactor those to
  explicit assignment first, with tests, then trim. Deferred-with-reason in
  PROGRESS Stage 4b.
- **D3 — Laravel major upgrade to clear CVE-2026-48019**, then promote the
  `composer audit` job to a **required** check (Layer 3i). Its own project; the
  Dependency Audit stays intentionally red until then — do not silence it.
- **D4 — DG1 silent-recording consent flow** (already resolved + in flight;
  release blocker). Not new work for this plan, but A1/A4/B1 must keep the
  consent path covered by tests as it lands. 🔒 legal wording = Achia's lawyer.
- **D5 — `/api/check` unauthenticated endpoint** — left intentionally for smoke
  tests. Revisit only if smoke moves to an authenticated health route.
- **D6 — Android release signing** (`app/android/app/build.gradle.kts` uses the
  debug config for release). Low priority while iOS-only, but wire a real
  release signing config from a git-ignored `key.properties` before any Android
  store release. 🔒 needs the keystore (Achia, never in repo).

---

## Suggested execution order (one batch per release-worthy milestone)

1. **A1, A2, A3, A4** — protect live users (the backwards-compat keystone +
   the two config/secret leaks + contract breadth). Security-meaningful →
   candidate `🚀 RELEASE MILESTONE` once green on staging.
2. **B1–B4** — test-wall completion + app-side input hardening.
3. **C1–C4** — CI hardening + coverage ratchet + required-check promotion.
4. **D-series** — only as each gate clears.

After Phase A lands green on staging, signal Achia: it's release-worthy
(app-first, then operator deploys the backend). Do not run the release yourself.

## Acceptance for the whole plan

- The backwards-compat test (A1) demonstrably fails on a reintroduced
  shape-divergence and passes after revert.
- No realtime/Pusher secret or host literal remains in `app/lib/` (A2).
- `.env.example` is prod-safe (A3); every critical + patent endpoint has a
  contract test (A4).
- iOS integration tests run in CI (B1); smoke gates staging health (B2).
- Provider whitelist + scoped `exists:` rules merged with tests (B3, B4).
- Coverage floors raised to match new actuals (C3); required-check set documented
  and applied (C4).
- Every gated item (D-series) is parked in `NEEDS-ACHIA.md` with its gate named.
