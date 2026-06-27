# Reacti Project — Status Handoff — 2026-05-29

**Date:** 2026-05-29
**Operator:** Achia (achia.rosin19@gmail.com), repo owner `reacti25`
**Purpose:** End-of-marathon status snapshot. Upload this to a fresh chat session in this project so the next operator (a new Claude conversation, or future Achia returning to this work) has full context without re-discovering everything.

**Companion documents in the repo (read in this order if you are a new operator):**
1. `HANDOFF-deploy-2026-05-24.md` — post-mortem of the 2026-05-23 chat-shape bug incident. Explains why we built any of this.
2. `docs/PLAN-staging-and-testing-2026-05-24.md` — the forward plan being executed. Six phases. Phase 1 and 2 are complete; Phase 3 is in progress.
3. **This document** — current state as of 2026-05-29.

---

## 0. How to use this document

- **Section 1** is the headline. Read it first.
- **Section 2** is the four things that came out of today's audit that aren't obvious from the deploy dashboards. Read these before doing anything else.
- **Section 3** is what's actually working — useful for morale and for knowing what NOT to break.
- **Section 4** is the phase-by-phase plan progress in a single table.
- **Section 5** is the verbatim audit Claude Code produced on 2026-05-29 — keep for technical reference.
- **Section 6** is the open task list including deferred items.
- **Section 7** is the prioritized next-actions list.
- **Section 8** is the decisions still waiting on Achia.
- **Section 9** is how Achia works and what a new chat should know about her communication preferences.

---

## 1. TL;DR

**Production is up. Staging is up. Nothing is on fire.**

But four things from today's audit are worth knowing before resuming work:
1. Production is NOT running the code on `main` — it's running a `develop` commit (`421502e`).
2. The production deploy SSH key on Achia's machine no longer works. We don't know if the GitHub Actions automated deploy still works, because it hasn't been used since 2026-05-23.
3. The staging database is empty (0 users). It works as a deploy target but has no test data.
4. `main` is 154 commits behind `develop`. The first develop → main promotion will ship a very large batch through a pipeline that hasn't been exercised in 6 days.

The most important next action for the week is to verify the production deploy path actually works. Until that's known-good, the whole promotion plan rests on an untested foundation.

The staging environment itself, the protect-main ruleset, Phase 3 layers 3a/3b/3i, and the Phase 3c migration tests PR are all working as intended.

---

## 2. The four critical flags — in plain words

### Flag 1 — Production is running `develop`, not `main`

On 2026-05-23 (the day of the chat-shape bug incident), the deploy that ran shipped a specific develop commit (`421502e`) via a manual `workflow_dispatch`. That code is what is live in production right now. Meanwhile `main` sits at a different commit (`f32d54c`) that has never been deployed.

This isn't a bug. It's what happened during incident recovery. But it means "main = what's in production" is a story we want to be true and isn't yet. When Phase 4 (the promotion gate) is built and the first proper promotion runs, `main` will jump forward by 154 commits in one go.

### Flag 2 — The production deploy path is unverified

When Claude Code tried to SSH into production from Achia's Windows machine using `~/.ssh/reacti_deploy`, the server rejected the key. The key is being offered correctly; the server is saying "no."

The GitHub Actions deploy uses a separate copy of this key stored in the `DEPLOY_SSH_PRIVATE_KEY` secret. That copy was updated on 2026-05-23, possibly to a newer key than the one still on Achia's local machine. So the automated production deploy MIGHT still work — but it hasn't been used since 2026-05-23, and nobody has verified.

**This is the single most important thing to verify this week.** Until it's known-good, we don't have a confirmed path to ship a hotfix to production if one were needed.

Suggested verification: push a tiny, low-risk change through develop → main → production (or trigger the production deploy workflow manually with a clean dry-run) and watch what happens. If it fails, re-issue the SSH key and re-install it on the server.

### Flag 3 — Staging database is empty (0 users)

Staging's schema is in place and migrations run cleanly on every deploy, but the "copy sanitized data from production" step (`backend/scripts/seed-staging-from-prod.sh`) has never been executed. So staging works as a deploy target — the Laravel app boots and `/api/check` returns 200 — but there's no data to test login/chat/etc. flows against.

This needs to be resolved before Phase 3e (smoke tests) and Phase 3f (iOS integration tests) can do anything meaningful. Either run the seed script (~30 minutes), or accept that until smoke/integration layers exist there's nothing to test against anyway.

### Flag 4 — `main` is 154 commits behind `develop`

This is by design — `develop` is the sandbox, `main` is sacred, and `main` only moves through the (not-yet-built) promotion gate. But the gap is now large enough that the first promotion will be a big deploy: 154 commits' worth of changes landing on production at once, through a pipeline that hasn't run in 6 days.

The longer we wait to do the first promotion, the bigger and riskier it gets. Strategy options:
- Build Phase 4 (promotion gate) sooner, then promote a smaller batch.
- Or do a one-time controlled "catch-up" promotion before resuming normal cadence.
- Or change the deploy trigger to ship `develop` directly to production (the easy answer, but it abandons the whole "main is sacred" architecture we're building toward).

This needs a decision before the gap grows further.

---

## 3. What's working — wins to date

- **Phase 1 (lock down `main`)** — complete and verified active. `protect-main` ruleset enforces: no direct pushes, no force-pushes, no deletions, PRs must come from `develop` only, require 1 code-owner approval, 3 required status checks (PHP Tests, Flutter Analyze & Test, "Source must be develop"). No bypass actors — not even admins can skip. The Flutter CI deadlock from before Phase 1 is also fixed (verified by the backend-only PR #104 successfully reporting on it).
- **Phase 2 (staging environment)** — complete and verified working. `staging.reacti.io` auto-deploys from `develop` on every push. Has its own database (`reacti-staging`), its own APP_KEY, neutered MAIL_MAILER and BROADCAST_DRIVER so it can't email real users or broadcast to real iOS clients. SSL via Let's Encrypt active.
- **Phase 3 layer 3i (Dependency Audit cleanup)** — complete. PR #103 cleared 24 → 0 advisories. The Backend CI Dependency Audit job is green for the first time in repo history.
- **Phase 3 layers 3a + 3b (static analysis + unit tests)** — already in place. PHPStan, Pint, and PHPUnit run inside the `PHP Tests` job on every PR; failures block merging. PHP Tests is required on `main`.
- **PR #104 (Phase 3c — migration tests)** — open, all 6 CI checks green, ready to merge. The migration that triggered the 2026-05-23 incident would have been caught here.
- **Production database password rotated.** The leaked production reacti-user password is dead (verified). Performed 2026-05-26 after three failed attempts (see Section 9 for the lessons learned).

---

## 4. Phase-by-phase plan progress

### Top-level phases

| Phase | Status | Note |
|---|---|---|
| 1 — Lock down main | ✅ Complete | Ruleset active, no bypasses, source-branch check live, CODEOWNERS in place. Flutter CI deadlock fixed. |
| 2 — Staging environment | ✅ Complete (1 follow-up) | `staging.reacti.io` live, auto-deploys from `develop`, isolated DB/key/mail/broadcast. Follow-up: DB never seeded; some third-party keys (AWS, Firebase) still point at prod. |
| 3 — Test wall | 🟡 In progress | The heart of the plan. Layer breakdown below. |
| 4 — Promotion gate | ⛔ Not started | No `promote-develop-to-main.yml` yet. This is what's missing to safely move develop → main. |
| 5 — iOS TestFlight / App Store | ⛔ Not started | A shell `ios-release.yml` exists, but no App Store secrets, no working pipeline. |
| 6 — Docs / runbooks | 🟡 Barely started | `CLAUDE.md` references the plan; the plan itself exists. The release-runbook, emergency-rollback, and testing-strategy docs are not written. |

### Phase 3 layer breakdown

| Layer | Status | Reality check |
|---|---|---|
| 3a — Static analysis (PHPStan + Pint) | ✅ Done | Runs inside the "PHP Tests" job on every PR; failures block. Working. |
| 3b — Unit / Feature tests | ✅ Done | 47 test files covering Auth, Chat, Patent flow, Groups, Friends. Run on every PR. Required on `main`. |
| 3c — Migration tests | 🟡 In progress | Workflow built, PR #104 open to develop, all green — but not merged yet. |
| 3d — API contract tests | ⛔ Not started | **This is the critical one** — the layer specifically designed to catch the 2026-05-23 chat-shape bug. No `backend/tests/Contract/` directory exists. |
| 3e — Smoke tests | 🟡 Partial | `SmokeTest.php` + `post-deploy-smoke.yml` exist, but smoke-user secrets aren't set and the workflow isn't auto-triggered after staging deploy. Can't actually run end-to-end yet. |
| 3f — iOS integration tests | ⛔ Not started | No `app/integration_test/` files. |
| 3g — Backwards-compat test | ⛔ Not started | No pinned live-version tag, no workflow. |
| 3h — Performance regression | ⛔ Not started | — |
| 3i — Security audit | ✅ Done | Dependency Audit job green (PR #103 cleared 24 advisories). Not yet a required check on `main`. |

**Verified-still-working checks on completed items:** Phase 1 ruleset (verified active via GitHub API). Flutter CI deadlock (verified fixed via the backend-only PR #104). Staging deploy (verified current and serving 200). 3a / 3b / 3i (verified green on latest develop runs). The completed items are genuinely working, not merged-but-broken.

---

## 5. Full audit report (verbatim from Claude Code, 2026-05-29)

The text below is the raw audit Claude Code produced when asked for a full status check on 2026-05-29. Kept for technical reference — for plain-language understanding, see Sections 1–4 above.

> **Reacti Status Report — 2026-05-29**
>
> **⚠️ FLAGS — read these first**
>
> Four things came up during the audit that are not what you'd expect:
> 1. **Production is NOT running main.** The last successful production deploy (2026-05-23) was a manual run from the develop branch and shipped commit `421502e`, which lives only on develop, not on main. The deploy that was supposed to ship main (PR #98) was cancelled and never re-run. So "main = what's in production" is not true right now.
> 2. **I could not get into the production server.** The production deploy SSH key on your machine (`~/.ssh/reacti_deploy`) is being rejected by the server (the key is offered, the server says "no"). The host itself is fine — it's the key that's no longer accepted. This means (a) I couldn't directly inspect prod's code, logs, or DB, and (b) there's an open question of whether the automated production deploy would even work today, since it hasn't run since 2026-05-23.
> 3. **The staging database is empty (0 users).** Staging's schema is live and migrations run on every deploy, but the "copy sanitized data from production" step was never run. Staging works as a deploy target, but there's no data in it to test against yet.
> 4. **main is 154 commits behind develop.** That's by design (nothing has been promoted yet), but it means the first promotion to production will ship a very large batch of changes at once — and the production deploy path hasn't been exercised in 6 days.
>
> None of these are breaking production right now — both sites are up and serving users. But #1 and #2 together mean we don't have a verified, working path to ship a fix to production if we needed one today.
>
> ---
>
> **1. GITHUB REPO STATE**
>
> Branches. Eight remote branches exist. The ones that matter:
> - `main` — the production branch. At commit `f32d54c` (2026-05-24).
> - `develop` — the sandbox where everything lands first. At `6a15515` (2026-05-27).
> - `infra/phase-3c-migrations` — your current working branch, 3 commits ahead of develop, has the open PR.
> - The rest are old/stale (`feature/*`, `ci/*`) — leftovers, not in active use. (A big batch of ~30 old branches was just pruned during this audit's fetch — harmless cleanup.)
>
> **main vs develop:** main is 1 commit ahead (the deploy-workflow-enable commit that only exists on main) and 154 commits behind develop. In plain terms: develop has 154 commits' worth of work — all the refactors, enhancements, and testing infrastructure from the last weeks — that has never been promoted to production. This is the intended model (develop accumulates, main only moves through the promotion gate), but the gate (Phase 4) doesn't exist yet, so the backlog just keeps growing.
>
> **Open PRs:** Exactly one — PR #104, `infra/phase-3c-migrations → develop` (the migration-tests work). It's mergeable and all six checks are green (PHP Tests, Flutter Analyze & Test, Migration Tests, Dependency Audit, Build Android, Build iOS). Nothing is open against main.
>
> **protect-main ruleset:** Active, and well-configured. It enforces:
> - No deletion of main, no force-pushes, linear history required.
> - Every change must go through a PR with 1 approving review from a code owner.
> - Three required status checks must pass: PHP Tests, Analyze & Test (Flutter), and Source must be develop (the custom check that blocks any PR not coming from develop).
> - No bypass actors — literally no one, including admins, can skip these rules.
>
> One gap worth noting: the migration-tests and dependency-audit checks exist and pass but are not yet in the required list for main. They'll need to be added once they're stable on develop.
>
> **GitHub Actions secrets** (names only — all confirmed present, no values shown):
> - Production deploy: `DEPLOY_SSH_HOST`, `DEPLOY_SSH_PORT`, `DEPLOY_SSH_USER`, `DEPLOY_SSH_PRIVATE_KEY`
> - Staging deploy: `STAGING_DEPLOY_SSH_HOST`, `STAGING_DEPLOY_SSH_PORT`, `STAGING_DEPLOY_SSH_USER`, `STAGING_DEPLOY_SSH_PRIVATE_KEY`, `STAGING_DEPLOY_TARGET_PATH`
> - Not present: the smoke-test user secrets (`SMOKE_USER_A_*`, etc.) and any iOS / App Store secrets — expected, since those phases haven't started.
>
> **Last ~12 workflow runs:** Mostly green. The recent failures (two on the phase-3c branch on 2026-05-27) were intermediate steps while iterating on the migration-test CI — the final run on that branch is fully green, so they're resolved, not lingering problems. Everything on develop (the merges of #102, #103) passed.
>
> ---
>
> **2. PRODUCTION SERVER (reacti.io)**
>
> - Is `/api/check` returning 200? ✅ Yes — HTTP 200, "Project is running!", ~0.5s. Production is up and serving.
> - Last deploy / which commit? Last successful pipeline deploy was 2026-05-23 21:25 UTC, a manual run from develop, shipping commit `421502e`. No production deploy has run since. (See Flag #1 — this commit is on develop, not main.)
> - Errors in the last 24h of logs? ⚠️ Could not check — the production SSH key on the local machine is rejected (Flag #2), so `storage/logs/laravel.log` could not be read. No evidence of errors, but no confirmation either.
> - Drift between server and main? ⚠️ Yes. The server is running `421502e` (a develop commit); main is at `f32d54c`. They are not the same code. The app works, so the running code is functional — but it does not correspond to main.
>
> ---
>
> **3. STAGING SERVER (staging.reacti.io)**
>
> - Is `/api/check` returning 200? ✅ Yes — HTTP 200, ~1.0s.
> - Last deploy / which commit? 2026-05-27 07:57 UTC, auto-deployed from develop HEAD (`6a15515`, PR #103). Confirmed by file timestamps on the server matching the deploy run. Staging is current with develop. ✅
> - Is data isolated from production? ✅ Yes, and verified directly on the server:
>   - Separate database: `reacti-staging` (prod is `reacti_db`).
>   - `APP_ENV=staging`, its own APP_KEY (set, distinct from prod).
>   - `BROADCAST_DRIVER=null` (won't push real-time events through prod's Pusher) and `MAIL_MAILER=log` (won't send real emails).
>   - The staging DB has 0 users — concrete proof it's a separate database from prod (prod has real users). The flip side: it's also un-seeded (Flag #3).
>   - ⚠️ Partial gap: `AWS_BUCKET` and `FIREBASE_CREDENTIALS` are still set to production values. So staging could potentially write files to the prod S3 bucket or send Firebase push notifications. This is a known, tracked TODO for the Phase 5/6 sandbox-key swap — not yet closed.
>
> ---
>
> **4. STAGING + TESTING PLAN PROGRESS**
>
> (See Section 4 of this document for the same table.)
>
> ---
>
> **5. TASK LIST & DEFERRED ITEMS**
>
> There's no live task tracker in this session; this is reconstructed from the plan and saved notes.
>
> **Done recently:**
> - Production reacti DB password rotation — done 2026-05-26.
> - Phase 3i dependency advisories cleared — done (PR #103).
>
> **Explicitly deferred:**
> - **MariaDB root password rotation** — deferred by Achia's call. Reason: root DB access is localhost-only, so the risk is bounded to whoever already has shell access to the VPS. Re-trigger when: a teammate gains VPS access, OR a quieter maintenance window appears, OR the assumption about who's seen the old credential stops holding.
>
> **Things noticed today that aren't tracked anywhere yet (recommend tracking):**
> 1. Production deploy key rejected / prod-deploy path unverified (Flag #2).
> 2. Production running a develop commit instead of main (Flag #1).
> 3. Staging DB never seeded (Flag #3).
> 4. Migration Tests + Dependency Audit not yet promoted to required checks on main.
> 5. Staging's `AWS_BUCKET` / `FIREBASE_CREDENTIALS` still pointed at prod resources.
> 6. Deploy workflows use `composer update` / `npm install` (not `install` / `ci`), so prod/staging can resolve different dependency versions than CI tested — a reproducibility risk, documented in the workflow comments but not closed.
> 7. The known TLS override in the iOS app (`MyHttpOverrides` in `app/lib/main.dart`) — flagged in `CLAUDE.md` as a production TLS weakener, still on the cleanup list.
>
> ---
>
> **6. RISKS & URGENT ITEMS**
>
> **Could break production:**
> - **No verified path to deploy to production.** Between the rejected deploy key and main never having shipped, if a hotfix were needed today, we don't actually know that it would work. This is the most important thing to resolve.
> - **The eventual first promotion is a "big bang."** 154 commits landing on prod in one deploy, through a pipeline that's been idle 6 days, is high-risk. Smaller, sooner, tested promotions are safer than one giant one later.
>
> **Known security exposures (accepted/deferred):**
> - MariaDB root password not yet rotated (accepted, bounded to shell-access holders).
> - iOS app TLS override (accepted, on cleanup list).
> - Staging may touch prod S3/Firebase (partial isolation gap, tracked for Phase 5/6).
>
> **Needs attention soon (this week, not tonight):**
> - Confirm whether the production deploy pipeline's key still works. It's safe to leave overnight — production is up and stable.
>
> **Safe to sleep on:** Both servers are up, the ruleset is locked, the only open PR is green. Nothing is actively on fire.
>
> ---
>
> **7. WHAT'S NEXT**
>
> The single next action to start with tomorrow: verify the production deploy path. Specifically — confirm whether the `DEPLOY_SSH_PRIVATE_KEY` secret in GitHub still authenticates to the server (it may be a newer key than the rejected local copy — the secret was updated later the same day the local key was created). If it's broken, re-add the deploy public key to the server's `authorized_keys`. Until this is known-good, the whole promotion plan rests on an untested foundation. (~30–60 min, needs Achia for root access.)
>
> Then, in order:
> 2. Merge PR #104 (Phase 3c migration tests) into develop, then add Migration Tests and Dependency Audit to the required checks on main. (~15–30 min, low risk.)
> 3. Start Phase 3d (API contract tests) — the layer that would have caught the incident that started all this. It's the highest-value remaining work and the biggest single chunk. (~1–3 days; needs a one-time capture of real API responses from the live app.)
>
> **Decisions still waiting on the operator:**
> - The five open questions in the plan (§6): staging seed cadence, whether TestFlight auto-uploads, which integration tests are critical-path, how the "live App Store version" tag gets updated, and whether smoke users live in staging only or also prod.
> - Whether to seed staging now (it's empty) so the smoke/integration layers have something to test against.
> - How to handle the 154-commit gap — recommend planning a controlled first promotion soon (once Phase 3c/3d and the deploy path are solid) rather than letting it grow.
> - The MariaDB root rotation trigger.
>
> Per the plan's own rule, no new phase (3d, 4, etc.) should start without Achia's explicit go-ahead — so the above is a recommendation, not begun.

---

## 6. Open tasks and deferred items — consolidated list

### Active / open

- [ ] **Verify production deploy path works.** Most important. Either trigger a low-risk dry-run, or accept the risk and verify on first real promotion.
- [ ] **Merge PR #104** (Phase 3c — migration tests workflow). Green and ready.
- [ ] **Promote Migration Tests + Dependency Audit to required checks** on `protect-main` ruleset, after ~5 PRs have landed with them green (observe-first policy).
- [ ] **Phase 3d — API contract tests.** Pause for design check-in before coding starts (Claude Code asked for this). The bug-prevention layer that would have caught the 2026-05-23 incident.
- [ ] **Seed the staging database** with sanitized production data — or accept it stays empty until smoke tests are built.
- [ ] **Plan first develop → main promotion.** 154-commit gap, growing.

### Explicitly deferred

- [ ] **Rotate MariaDB root password.** Bounded risk (localhost-only). Re-trigger conditions: a teammate gains VPS access, OR a quieter maintenance window, OR a discovery that more people than expected have seen the credential.

### Lurking but not yet a task

- Staging's `AWS_BUCKET` and `FIREBASE_CREDENTIALS` still point at production. Tracked for Phase 5/6.
- Deploy workflows use `composer update` / `npm install` rather than `composer install` / `npm ci` — reproducibility gap.
- iOS app TLS override (`MyHttpOverrides` in `app/lib/main.dart`) — known production TLS weakener, on cleanup list.

---

## 7. Recommended next actions — prioritized

1. **(This week, ~30–60 min)** Verify the production deploy path actually works. Without this, nothing else in the plan rests on solid ground. Suggested approach: open a trivial PR from develop to main (a comment-only change), let it merge through the protected gate, and watch the production deploy workflow run. If it fails, re-issue the deploy SSH key and re-install it on the server.

2. **(This week, ~15 min)** Merge PR #104 to get Phase 3c (migration tests) onto `develop`.

3. **(Multi-day, after design discussion)** Phase 3d — API contract tests. The bug-preventer the entire plan was built for. Claude Code will pause for a design check-in before starting; that conversation needs to cover: which endpoints to lock down first, how fixtures get captured from the live App Store iOS app, where they get stored, how shape diffs are surfaced in CI output.

4. **(Anytime, optional)** Seed staging from a sanitized production dump so subsequent layers (3e smoke, 3f iOS integration) have realistic data to test against.

5. **(Lower priority)** Phase 3e (smoke tests expansion), 3h (performance regression). Small, can slot in alongside other work.

6. **(Pause before starting)** Phase 3f (iOS integration tests) and 3g (backwards-compat test). Both involve Apple Developer account and macOS-runner setup — design discussion required before coding.

7. **(Eventually)** Phase 4 (promotion gate), Phase 5 (iOS pipeline), Phase 6 (docs).

---

## 8. Open decisions waiting on Achia

These are the choices that, once made, unblock further work. Most are documented in the plan as "Open decisions" but listed here for visibility.

1. **Staging seed cadence.** Weekly cron, on-demand only, or never (accept empty)?
2. **TestFlight build automation.** Should every push to develop auto-build and upload a TestFlight build, or only on-demand?
3. **iOS integration test budget.** Which tests are critical-path (run on every PR) vs nice-to-have (nightly only)? Constrained by GitHub Actions macOS quota (counts 10× against the free tier).
4. **"Currently live App Store version" pinning.** How does the backwards-compat test know which app version to test against — manual tag update, or auto-pulled from App Store Connect?
5. **Smoke user accounts.** Live in staging only, or also in production for post-deploy verification?
6. **154-commit `main` vs `develop` gap.** Controlled promotion now to shrink it? Or build Phase 4 first?
7. **MariaDB root rotation trigger.** What conditions would change the calculus and warrant doing it sooner?

---

## 9. Context for a new chat session

If a new Claude conversation is reading this to pick up the project, the things you most need to know that aren't in the plan or the audit:

### About the operator (Achia)

- Non-developer. Runs the business; doesn't write code. Wants step-by-step, beginner-friendly explanations.
- Long messages overwhelm her. Default to short, action-focused responses. One concrete action per turn when possible.
- When showing options, give a clear recommendation. Don't make her choose between abstract trade-offs.
- PowerShell on Windows. Has `ssh-keygen`. Can't run Bash scripts natively. Files at `C:\Users\Achia\`.
- The Reacti repo on her machine is at `C:\Users\Achia\reacti\`.
- Her offline secrets folder is `C:\Users\Achia\reacti passwords\` (note the space). Generated passwords get saved there, not in any git repo.
- Hostinger's in-browser Terminal (hPanel → VPS → Browser Terminal) is her preferred way to run server-side commands. Right-click or Ctrl+Shift+V to paste (Ctrl+V doesn't always work).

### About security habits being built

Achia has, multiple times during this project, screenshotted or pasted credentials directly into chat. This is a habit being actively broken. Going forward:
- Never ask her to screenshot a file containing secrets — ask her to grep out just the non-secret lines first.
- When discussing leaked credentials, describe them by context (e.g., "the reacti user password from the .env"), don't quote their actual values.
- When she needs to verify a leaked credential is dead, give her a `read -s` prompt to paste the OLD password — never a command line that puts it in plain text.

### About the architecture quirks discovered during Phase 2

These are CloudPanel / Hostinger specifics that are easy to re-discover painfully. Save the time:
- **CloudPanel database naming.** Database name and user name must be the literal site-user string. For the `staging.reacti.io` site whose Linux user is `reacti-staging`, both the DB name and DB user are `reacti-staging` (with a hyphen). Production follows the same pattern — both are `reacti`.
- **CloudPanel document root.** Generic-template sites set the document root from `Settings → Domain Settings → Root Directory`, not from the vhost editor (vhost editor uses `{{root}}` template placeholders that get overwritten on every save). Set the relative path to `staging.reacti.io/public` (with `/public`).
- **MariaDB root requires `-h 127.0.0.1`.** Default Unix-socket auth tries `root@localhost`, which has a separate password from `root@127.0.0.1`. Always pass `-h 127.0.0.1` when connecting as root.
- **MariaDB root credentials are obtained from `clpctl db:show:master-credentials`** (parses cleanest from the `Connect Command:` line at the bottom: `mysql -h'127.0.0.1' -P'3306' -u'<user>' -p'<password>' -A`).
- **The `reacti` MariaDB user is `'reacti'@'%'`** (wildcard host). When rotating, ALTER USER references the `%` host, not `localhost`.
- **`reacti` user can't ALTER itself.** Lacks the `CREATE USER` privilege. Password rotations need root MariaDB access.
- **VPS host keys rotated on 2026-05-23** during the auto-backup restoration after the chat bug incident. New clients will hit a `known_hosts` mismatch on first SSH; resolve with `ssh-keygen -R 72.61.202.136`.

### About the iOS app

- The app is Flutter, NOT React Native, despite being named "Reacti."
- iOS-only. No Android pipeline.
- Apple Developer account exists ($99/year, already paid). TestFlight access included.
- Achia develops on Windows — no local Mac. iOS work happens on GitHub macOS runners or on her personal iPhone via TestFlight.

### About the repo conventions

- Branch names: `infra/phase-N-description` for plan-execution work, `feature/X` for features, `ci/X` for CI-only changes.
- PRs target `develop`, never `main`. `protect-main` enforces this.
- Squash and merge is the default for PRs.
- The Backend CI "Dependency Audit" job: was failing forever as a known-broken check before Phase 3i. It's now green. Add it to required-on-main after ~5 clean PRs.

---

## 10. The single rule that summarizes the whole project

**No code reaches production until it has been deployed to staging, verified by automated tests at every layer, AND personally validated by Achia on her iPhone via TestFlight.**

If that rule is followed, the 2026-05-23 incident cannot repeat.

---

**End of status handoff.** Upload this file alongside `HANDOFF-deploy-2026-05-24.md` and `docs/PLAN-staging-and-testing-2026-05-24.md` to any new chat session for full context.
