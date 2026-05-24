# Reacti Staging + Comprehensive Testing Infrastructure — Implementation Plan

**Date:** 2026-05-24
**Operator:** Achia (achia.rosin19@gmail.com), repo owner `reacti25`
**Companion document:** `HANDOFF-deploy-2026-05-24.md` (the post-mortem of the incident that triggered this plan)
**Purpose:** Build a staging environment and a multi-layer testing wall so that nothing reaches production — neither the Hostinger backend nor the App Store iOS app — without being fully verified first.
**Constraints (hard, non-negotiable):**
1. **Zero additional monthly cost.** Single Hostinger VPS only. No new VPS, no paid CI plans, no paid cloud Mac services.
2. **Windows-only dev machine.** Achia runs PowerShell on Windows. No local Mac. iOS work happens in CI or on her personal iPhone via TestFlight.
3. **iOS-only app.** The mobile app is Flutter, distributed only via Apple App Store. No Android pipeline to consider.
4. **Do not break the existing deploy pipeline.** `backend-deploy.yml` works. Treat it as load-bearing.
5. **Do not break existing CI.** Other workflows on `develop` must keep running.
6. **The live App Store version of the iOS app must keep working at every step.** Backwards compatibility is the prime directive.

---

## 0. North Star

`develop` is the sandbox where every change lands first.
`main` is sacred. It is the *only* branch that ships to production — both Hostinger backend AND the App Store iOS build.
A wall of automated tests stands between `develop` and `main`.
Code crosses from `develop` to `main` ONLY when every test passes AND Achia approves manually after a TestFlight check on her own iPhone.

There is no other path to `main`. Ever.

---

## 1. The lesson driving this plan

On 2026-05-23, the first automated backend deploy succeeded perfectly at the infrastructure level — but introduced a bug that emptied every private chat in the live iOS app. CI was fully green. The deploy pipeline did exactly what it was told to do. The bug was discovered by Achia opening the app and noticing it. Recovery required a Hostinger auto-backup restore that cost ~3 days of real user activity.

The root cause class: a backend code change altered the *shape* of an API response. The deployed Laravel code was valid PHP, the migrations ran, the server returned HTTP 200 — but the field structure no longer matched what the live App Store iOS app expected to parse. There was no automated test that compared "what does the iOS app expect from this endpoint" against "what does the backend now return." So the divergence was invisible until a human opened the app.

**Every part of this plan is built to make that class of bug catchable before it reaches production.**

---

## 2. Architecture overview

### Two backend environments, one VPS

```
Hostinger VPS srv1153282.hstgr.cloud (72.61.202.136)
├── /home/reacti/htdocs/reacti.io/           ← PRODUCTION
│   └── DB: reacti_db
└── /home/reacti/htdocs/staging.reacti.io/   ← STAGING (NEW)
    └── DB: reacti_staging
```

Both sites are CloudPanel-managed Laravel installs on the same VPS. Same machine, same RAM, separate folders, separate databases, separate domains, separate SSL certs. Cost: $0 additional.

### Three iOS app environments, one Apple developer account

```
Apple Developer account ($99/yr, already paid)
├── App Store (live)         ← Built from `main`, points at https://reacti.io
├── TestFlight (beta)        ← Built from `develop`, points at https://staging.reacti.io
└── GitHub macOS CI runner   ← Built per-PR, ephemeral, runs integration tests in iOS Simulator
```

The TestFlight build is the human gate. The GitHub CI build is the automated gate.

### Branch → environment mapping

```
develop  → staging.reacti.io  (auto-deploy on push)
         → TestFlight         (auto-build + upload on push, after all tests pass)
         → ephemeral CI       (every push runs the full test wall)

main     → reacti.io          (auto-deploy on push)
         → App Store          (auto-build + upload on push, after all tests pass)
```

### The promotion gate

```
develop  ──[ all tests pass ]──[ Achia approves TestFlight on iPhone ]──>  main
```

No other path. Enforced by GitHub branch protection.

---

## 3. Phase-by-phase plan

### Phase 1 — Lock down `main` and clean up the incident (immediate, ~2 hours)

**Goal:** Make `main` untouchable except via a fully-tested PR from `develop`. Eliminate the deadlocks and disabled rules left over from the incident.

**Deliverables:**

1. Re-enable the `protect-main` ruleset in `Settings → Rules → Rulesets`. It was disabled on 2026-05-23 and never re-enabled.
2. Fix the `flutter-ci.yml` deadlock. Two options — pick one:
   - **Option A (recommended):** Remove `paths: [app/**]` from the trigger so the job always runs (and skips work it doesn't need to do via fast-fail).
   - **Option B:** Remove "Flutter Analyze & Test" from the list of required status checks on `main`.
3. Confirm `develop` branch protection is active (it was admin-bypassed once during the npm-install fix on 2026-05-23).
4. Add a CODEOWNERS file requiring Achia's review on any PR that touches `.github/workflows/**`, `backend/database/migrations/**`, or `app/lib/features/chat/**`.
5. Configure the `protect-main` ruleset to require:
   - PR source = `develop` only (block all other source branches)
   - All status checks listed in Phase 3 must pass
   - At least one approval (Achia)
   - No force pushes, no deletions
6. Investigate and either fix or document the Backend CI #201 failure on develop's recent merge commit.

**Success criteria:** No human can push to `main` directly. No PR to `main` can merge without all checks green AND Achia's approval. The Flutter CI deadlock is gone.

---

### Phase 2 — Stand up `staging.reacti.io` on the existing VPS (1–2 days)

**Goal:** A persistent staging copy of the backend, hosted on the same VPS, costing nothing extra, automatically updated whenever `develop` changes.

**Deliverables:**

1. **DNS:** Add an A record `staging.reacti.io → 72.61.202.136` in the domain registrar.
2. **CloudPanel:** Create a second PHP site:
   - Domain: `staging.reacti.io`
   - User: `reacti-staging` (separate Linux user for isolation)
   - PHP version: 8.3 (same as production)
   - Document root: `/home/reacti-staging/htdocs/staging.reacti.io/`
3. **SSL:** Issue a Let's Encrypt certificate for `staging.reacti.io` via CloudPanel.
4. **Database:** Create a separate MySQL database `reacti_staging` with a dedicated user `reacti_staging_user`. Seed it once with a sanitized copy of production data (PII scrubbed — see the seeding script deliverable below).
5. **Environment file:** Copy production `.env`, change:
   - `APP_URL=https://staging.reacti.io`
   - `APP_ENV=staging`
   - `DB_DATABASE=reacti_staging`
   - `DB_USERNAME=reacti_staging_user`
   - `DB_PASSWORD=<staging password>`
   - All third-party API keys point at sandbox/test modes where available
6. **SSH access for staging deploy:** Install the same `github-actions-reacti-deploy` public key for the `reacti-staging` user, OR reuse root with a different target path. Recommendation: separate SSH key `reacti_deploy_staging` for least-privilege.
7. **New GitHub Actions secrets:**
   - `STAGING_DEPLOY_SSH_HOST` = `72.61.202.136`
   - `STAGING_DEPLOY_SSH_PORT` = `22`
   - `STAGING_DEPLOY_SSH_USER` = `reacti-staging` (or `root` if reusing)
   - `STAGING_DEPLOY_SSH_PRIVATE_KEY` = the new private key
   - `STAGING_DEPLOY_TARGET_PATH` = `/home/reacti-staging/htdocs/staging.reacti.io/`
8. **New workflow** `.github/workflows/staging-deploy.yml`:
   - Copy of `backend-deploy.yml` adapted for staging
   - Trigger: `push: branches: [develop]` + `workflow_dispatch`
   - No production environment gate (auto-deploys)
   - Uses staging secrets
9. **Seeding script** `backend/scripts/seed-staging-from-prod.sh`:
   - mysqldump production DB
   - Scrub PII (emails → fake@example.com, phone numbers → 555-XXXX, names → faker-generated)
   - Load into staging DB
   - Run once during initial setup, then optionally on a weekly cron

**Success criteria:** Every push to `develop` automatically appears at `https://staging.reacti.io` within ~1 minute. Hitting `https://staging.reacti.io/api/check` returns 200. The staging database is independent — running migrations against staging never affects production.

---

### Phase 3 — Build the test wall (THE HEART OF THIS PLAN)

**Goal:** Catch every class of bug that could ship to production, especially the API-shape-divergence class that caused the 2026-05-23 incident. Multiple independent layers; each one catches a different category of problem.

**This phase is intentionally over-engineered. The cost of false positives is annoyance. The cost of false negatives is 3 days of user data.**

#### Layer 3a — Static analysis (already partial)

PHPStan + Laravel Pint. Already configured. Make them required status checks on every PR to `main`.

*Catches:* type errors, undefined variables, code style drift.

#### Layer 3b — Unit tests (already partial)

The existing `backend/tests/Unit/` and `backend/tests/Feature/` PHPUnit suites. Already run on every PR. Make them required.

*Catches:* logic bugs inside individual classes/functions.

#### Layer 3c — Migration tests (NEW)

A new GitHub Actions job that:
1. Spins up a fresh MySQL container
2. Runs `php artisan migrate` from scratch — must succeed
3. Runs `php artisan migrate:rollback --step=N` where N is the number of new migrations in the PR — must succeed
4. Runs `php artisan migrate` again — must succeed
5. Runs all seeders — must succeed

*Catches:* migrations that fail on a clean DB, migrations that can't roll back, seeders that break after schema changes. Would have helped on 2026-05-23 because the `drop_unused_cms_and_job_categories_tables` migration would have been verified to roll back cleanly.

#### Layer 3d — API contract tests (NEW, CRITICAL — this is the one that would have caught last night's bug)

A new test suite `backend/tests/Contract/` that locks down the exact response shape of every endpoint the iOS app calls. Implementation:

1. **Capture the source of truth.** Run the iOS app (in TestFlight or simulator) against the *currently live* production backend and record every API request/response pair into JSON fixtures stored in `backend/tests/Contract/fixtures/`. This is a one-time capture per endpoint, refreshed whenever we deliberately change a contract.
2. **Generate schema files.** From the captured fixtures, generate JSON Schema files describing the exact shape (field names, types, required vs optional, array vs object) of each response.
3. **Write contract tests.** For each endpoint, a PHPUnit test that:
   - Calls the endpoint with the captured request
   - Validates the response against the JSON Schema
   - FAILS if any field is missing, renamed, retyped, or restructured
4. **Endpoints to lock down** (minimum set — expand to cover everything in `app/lib/features/*/data/`):
   - `POST /api/login`
   - `POST /api/register`
   - `GET  /api/user`
   - `GET  /api/chats` (list)
   - `GET  /api/chats/{id}/messages` (the one that broke)
   - `POST /api/chats/{id}/messages` (send)
   - `GET  /api/friends`
   - `POST /api/friends/request`
   - `GET  /api/groups`
   - `GET  /api/groups/{id}/messages`
   - All endpoints under the "patent flow"
5. **CI integration.** Runs on every PR. Failure blocks merge to `main`.

*Catches:* the exact bug from 2026-05-23. If develop changes the shape of `/api/chats/{id}/messages`, the contract test fails immediately, and the PR cannot reach main.

*Maintenance:* When you deliberately want to change a contract, you regenerate the fixtures AND update the iOS app together in a coordinated release.

#### Layer 3e — Smoke tests (expand existing)

The existing `backend/tests/Smoke/SmokeTest.php` already exists with `workflow_dispatch` trigger. Expand it to cover, against the actual staging server:

1. Health check (`/api/check` returns 200)
2. Login flow (smoke user A and smoke user B)
3. List private chats (both users)
4. Send a private chat message from A to B
5. Fetch messages on B's side, verify A's message is there with correct content
6. Group chat: send and receive
7. Friends: list and request
8. The full patent flow end to end
9. Logout

Wire it to the `workflow_run` trigger so it runs automatically after every staging deploy.

*Catches:* end-to-end breakage that unit tests miss. Real database, real server, real network.

#### Layer 3f — iOS integration tests in CI (NEW)

The most powerful and most expensive layer. Uses Flutter's `integration_test` package:

1. Add Flutter integration tests under `app/integration_test/` covering the same flows as the smoke tests but driven from the iOS app side.
2. New workflow `.github/workflows/ios-integration-test.yml` that runs on `macos-latest` GitHub runner:
   - Boots an iOS Simulator
   - Configures the Flutter app to point at the ephemeral test backend (or staging)
   - Runs the integration tests
   - Reports pass/fail
3. Runs on every PR to `main` and every push to `develop`.

*Catches:* the iOS app's actual rendering and interaction with the backend. If a backend response shape change causes "private chats appear empty" on the iOS side, this test fails — even though contract tests would also catch it, this is a belt-and-suspenders check from the app's perspective.

*Budget consideration:* macOS runner minutes count 10x against GitHub Actions free quota. Run iOS integration tests only on (a) PRs to `main`, (b) merges to `develop`, NOT on every push within a develop PR. Keep test suite under 10 minutes wall clock.

#### Layer 3g — Backwards compatibility test (NEW)

The single most important test for protecting live users. Verifies that the version of the iOS app *currently in the App Store* still works against the new backend.

1. Pin the live App Store version (e.g., `v2.4.1`) as a git tag in the repo.
2. New workflow that checks out the pinned tag, builds it in CI, runs integration tests against the develop-deployed staging backend.
3. If any integration test fails, the new backend has broken backwards compatibility — the PR cannot merge to `main`.
4. To intentionally release a breaking backend change, the workflow is updated to point at a newer pinned tag AFTER the corresponding new iOS app version has rolled out to users.

*Catches:* any backend change that breaks users on the current production app version, even if develop's iOS app code has been updated to handle it.

#### Layer 3h — Performance regression (NEW, lightweight)

A simple check: hit 5 key endpoints against staging, record response times, fail if any endpoint is >2x slower than its rolling 7-day baseline.

*Catches:* accidentally-introduced N+1 queries, missing indexes after migrations.

#### Layer 3i — Security check (already partial)

The existing Backend CI Dependency Audit job. Currently failing — needs a dependency-refresh pass to clear known advisories. Once green, make it required.

*Catches:* known CVEs in dependencies.

#### Summary of test layers

| Layer | What it catches | Runs on | Required for main merge? |
|---|---|---|---|
| 3a Static analysis | Type/style errors | every push | YES |
| 3b Unit tests | Class-level logic bugs | every push | YES |
| 3c Migration tests | Migrations that can't apply/rollback | every push | YES |
| 3d API contract tests | Response shape drift (the 5/23 bug) | every push | YES |
| 3e Smoke tests | End-to-end backend flow breakage | post-staging-deploy | YES |
| 3f iOS integration tests | iOS app + backend integration | PRs to main, develop pushes | YES |
| 3g Backwards compat | Live app version broken | PRs to main | YES |
| 3h Performance | Slowdowns | nightly + PRs to main | warn only |
| 3i Security audit | Known CVEs | every push | YES |

**Success criteria:** A PR to `main` cannot merge unless every "required" check above is green. The 2026-05-23 bug, replayed today, would be caught by layers 3d, 3e, 3f, and 3g — four independent failures.

---

### Phase 4 — The promotion gate workflow (1 day)

**Goal:** Make `develop → main` a single, well-defined, low-friction action that you cannot do incorrectly.

**Deliverables:**

1. New workflow `.github/workflows/promote-develop-to-main.yml`:
   - Trigger: `workflow_dispatch` (Achia clicks a button)
   - Steps:
     1. Verify latest commit on `develop` has a green staging deploy
     2. Verify all Phase 3 required tests are green on that commit
     3. Build a TestFlight version pointing at staging, upload it, post a message that Achia should now manually verify on her iPhone
     4. **PAUSE** for manual approval (a second `workflow_dispatch` confirmation, OR a GitHub Environment approval gate)
     5. After Achia approves: open a PR `develop → main` with an auto-generated body summarizing what changed and which tests passed
     6. Achia clicks Merge on the PR
     7. Merge to `main` fires the existing `backend-deploy.yml` (production deploy) AND a new `ios-app-store-release.yml` (App Store upload)
2. Update `protect-main` ruleset: PR source must be `develop`, all checks green, Achia approves.
3. Document the promotion runbook in `docs/release-runbook.md`.

**Success criteria:** Promoting takes 2 clicks from Achia (kick off the promotion workflow, then approve after TestFlight check). The only way code reaches `main` is through this workflow.

---

### Phase 5 — iOS TestFlight + App Store pipeline (2–3 days)

**Goal:** Automate the iOS build/sign/upload pipeline for both TestFlight (from `develop`) and App Store (from `main`). Uses GitHub macOS runners, no local Mac required.

**Deliverables:**

1. Generate App Store Connect API key (App Store Connect → Users and Access → Keys).
2. Generate iOS distribution certificate and provisioning profiles (one for TestFlight, one for App Store).
3. Add GitHub Actions secrets:
   - `APPSTORE_CONNECT_KEY_ID`
   - `APPSTORE_CONNECT_ISSUER_ID`
   - `APPSTORE_CONNECT_PRIVATE_KEY`
   - `IOS_DIST_CERT_P12` (base64)
   - `IOS_DIST_CERT_PASSWORD`
   - `IOS_PROVISIONING_PROFILE_TESTFLIGHT`
   - `IOS_PROVISIONING_PROFILE_APPSTORE`
4. New workflow `.github/workflows/ios-testflight.yml`:
   - Trigger: `push: branches: [develop]` (after all tests pass)
   - Build flavor: staging (`API_BASE_URL=https://staging.reacti.io`)
   - Upload to TestFlight
5. Update existing `ios-release.yml`:
   - Trigger: `push: branches: [main]`
   - Build flavor: production (`API_BASE_URL=https://reacti.io`)
   - Upload to App Store (manual review submission)
6. App-side: ensure `app/lib/config/api_config.dart` (or equivalent) reads `API_BASE_URL` from `--dart-define` at build time so the same codebase can build either flavor.

**Success criteria:** A push to `develop` produces a TestFlight build on Achia's iPhone within ~15 minutes, pointed at staging. A push to `main` produces an App Store-ready build pointed at production.

---

### Phase 6 — Documentation and runbooks (ongoing)

**Goal:** Make the system survivable when Achia, Claude Code, or any other operator is not available.

**Deliverables:**

1. Update `CLAUDE.md` with the new branch model and promotion rule.
2. New doc `docs/staging-environment.md` — what staging is, how to access it, how to seed it.
3. New doc `docs/testing-strategy.md` — every test layer, what it catches, how to add a new contract.
4. New doc `docs/release-runbook.md` — step-by-step promotion from develop to main.
5. New doc `docs/emergency-rollback.md` — how to recover from a bad production deploy (with the snapshot/auto-backup lessons from 2026-05-23 baked in).
6. New doc `docs/adding-a-new-api-endpoint.md` — the checklist (write endpoint → write unit test → capture contract fixture → add to smoke test → add to iOS app → add to integration test).
7. Add `.gitattributes` with `* text=auto eol=lf` to fix the Windows CRLF problem permanently.

**Success criteria:** A new operator can read `docs/release-runbook.md` and `docs/emergency-rollback.md` and successfully ship or recover without prior knowledge.

---

## 4. Order of execution (recommended)

Some phases can run in parallel; others must be sequential.

```
Phase 1 (lock down main)           ──┐
                                     ├──> Phase 4 (promotion gate)
Phase 2 (staging environment)      ──┤        │
                                     │        ├──> Phase 6 (docs)
Phase 3 (test wall) — biggest      ──┘        │
                                              │
Phase 5 (iOS TestFlight/App Store) ──────────┘
```

Suggested calendar:
- **Day 1:** Phase 1 (must happen before anything else)
- **Days 2–3:** Phase 2 (staging up and running)
- **Days 2–10:** Phase 3 (test wall — biggest chunk, can start while Phase 2 finishes)
- **Day 11:** Phase 4 (promotion gate)
- **Days 12–14:** Phase 5 (iOS pipeline)
- **Throughout:** Phase 6 (docs)

---

## 5. Success criteria for the whole plan

The plan is done when ALL of the following are true:

1. ✅ A direct push to `main` is impossible.
2. ✅ A PR to `main` from any branch except `develop` is rejected automatically.
3. ✅ A PR to `main` from `develop` cannot merge unless every Phase 3 required test is green.
4. ✅ Every push to `develop` deploys to `staging.reacti.io` within ~1 minute.
5. ✅ Every push to `develop` produces a TestFlight build on Achia's iPhone within ~15 minutes.
6. ✅ A backend change that alters any iOS-facing API response shape is caught by at least 2 of the test layers (3d contract + 3f integration) BEFORE merge to `main`.
7. ✅ The currently-live App Store iOS version is verified against the new backend on every PR to `main`.
8. ✅ Replaying the 2026-05-23 chat-shape bug against the new system results in the PR being blocked at multiple test layers, with clear error messages pointing at the broken endpoint.

---

## 6. Open decisions Achia needs to make as Claude Code progresses

These are deliberately left open so Claude Code surfaces them when relevant:

- Does the staging database get seeded from prod weekly, or only on demand?
- Should TestFlight builds auto-upload on every develop push, or only on demand?
- Which Flutter integration tests are critical-path (must run on every PR) vs nice-to-have (nightly only)?
- For the backwards-compatibility test, how is the "currently live App Store version" tag updated — manually, or auto-pulled from App Store Connect API?
- Should the smoke users (`smoke-a`, `smoke-b`) live in staging only, or also in production for post-deploy verification?

---

## 7. How to hand this plan to Claude Code

Claude Code is a separate CLI tool that runs on Achia's Windows machine. To execute this plan with it:

### Step 1 — Save this document into the repo

Copy this file to `C:\Users\Achia\reacti\docs\PLAN-staging-and-testing-2026-05-24.md` and commit it to a new branch (e.g., `docs/staging-plan`), then merge to `develop`. This puts the plan inside the repo where Claude Code will see it during any session.

### Step 2 — Reference the plan in `CLAUDE.md`

Add a section near the top of `C:\Users\Achia\reacti\CLAUDE.md` that says something like:

```markdown
## Active project: staging + testing infrastructure

We are executing `docs/PLAN-staging-and-testing-2026-05-24.md`. Before working on
any task, read that plan and confirm which phase the work belongs to. Do not
start a new phase without explicit approval from Achia.
```

This means every future Claude Code session in this repo will automatically pick up the plan.

### Step 3 — Start Claude Code in the repo

Open PowerShell, navigate to the repo, and start Claude Code:

```
cd C:\Users\Achia\reacti
claude
```

(Assuming Claude Code CLI is already installed. If not, the install command is documented at https://docs.claude.com/en/docs/agents-and-tools/claude-code/quickstart .)

### Step 4 — Kick off Phase 1

In the Claude Code session, paste:

```
Please read docs/PLAN-staging-and-testing-2026-05-24.md and then begin Phase 1.
Stop after Phase 1 is complete so I can verify before we proceed to Phase 2.
```

Claude Code will read the plan, set up its own task list mirroring Phase 1's deliverables, and start executing. It will pause between major steps and confirm with you.

### Step 5 — Verify Phase 1 manually

After Claude Code says Phase 1 is done:
- Open GitHub → Settings → Rules → Rulesets → confirm `protect-main` is Active
- Try to push to main from a test branch → it should fail
- Confirm `flutter-ci` no longer deadlocks

Only after these manual checks pass do you say "Proceed to Phase 2."

### Step 6 — Repeat for each phase

Same pattern: tell Claude Code which phase to start, let it work, verify manually, then approve the next phase.

### Tips specific to using Claude Code

1. **Keep sessions focused on one phase at a time.** Claude Code does best when its context is one phase rather than the whole plan.
2. **Ask Claude Code to use git branches per phase.** E.g., "Do Phase 2 on branch `infra/phase-2-staging`." This way each phase is a reviewable PR.
3. **Demand that Claude Code writes tests BEFORE shipping infrastructure changes.** Phase 3 is the prime directive — every other phase exists to support it.
4. **Use `/clear` between phases to reset context.** This prevents Claude Code from carrying stale assumptions forward.
5. **When Claude Code suggests deviating from this plan, ask "why."** Deviations may be justified, but the plan was written to be coherent — changing one piece often affects others.
6. **If Claude Code gets stuck on the macOS runner (Phase 5),** check that the App Store Connect API key has the right roles — most TestFlight upload failures are due to insufficient key permissions.
7. **Snapshot the production VPS before Phase 2 deploys touch anything new on the server.** Even though staging is a new isolated site, having a fresh snapshot is cheap insurance.

---

## 8. Things that are explicitly NOT in scope for this plan

To keep the plan focused, these are deferred:

- Android app pipeline (the app is iOS-only).
- Multi-region deploys / CDN setup.
- Load testing / stress testing beyond the lightweight Layer 3h check.
- Replacing CloudPanel with a different control panel.
- Migrating off Hostinger.
- Building a separate admin dashboard environment.
- Real-time monitoring/alerting (Sentry, etc.) — worth doing but separate plan.

---

## 9. The single rule that summarizes everything

**No code reaches production until it has been deployed to staging, verified by automated tests at every layer, AND personally validated by Achia on her iPhone via TestFlight.**

If that rule is followed, the 2026-05-23 incident cannot repeat.

---

**End of plan. Good luck, Claude Code.**
