# Plan — Reset `develop` to a `main`-equal baseline, then rebuild in stages

**Date:** 2026-05-30
**Operator:** Achia (non-developer; keep explanations short and beginner-friendly, pause for her on anything destructive)
**For:** Claude Code, executing on Achia's Windows machine
**Related docs:** `docs/PLAN-staging-and-testing-2026-05-24.md`, `HANDOFF-status-2026-05-29.md`, `HANDOFF-private-chat-bug-2026-05-30.md`, `docs/refactor/big-refactor-plan.md`, `CLAUDE.md`

---

## 1. The goal, in plain language

`develop` has accumulated ~154 commits of refactor/rewrite work that has never reached production. That drift is causing real, visible bugs in the staging app that do **not** exist in the live App Store app — e.g. the one-to-one private chat renders a black screen on `develop` while it works on `main` (see `HANDOFF-private-chat-bug-2026-05-30.md`).

Achia wants a **clean, known-good baseline**: the **staging app (built from `develop`)** must look and behave **exactly like the production app (built from `main`)**. From that identical starting line, we re-introduce improvements slowly and verifiably.

So:

- **Roll the application code on `develop` back to match `main`** (so both apps behave identically).
- **Keep all testing and infrastructure work** (tests, CI/CD, the staging + TestFlight pipeline, docs).
- **Preserve every change already made in git history** — nothing is deleted, only set aside.
- Then rebuild forward in deliberate stages, each verified on staging before the next.

**Definition of done for the reset:** A build from `develop` (staging) and a build from `main` (production) are **functionally identical** — same screens, same behavior, including the private chat working in both. The only differences are the staging *identity* (bundle id/name/icon) and which server it points at.

---

## 2. Governing assumption (CONFIRM with Achia before destructive steps)

This plan assumes **"app code" = both the Flutter app (`app/lib/**`) AND the backend application logic (`backend/app/**`, `backend/routes/**`, behavior-changing migrations)** get reset to `main`, because "see the same in both apps" depends on both the app and the server it talks to behaving like production.

**Two nuances Claude Code must surface to Achia and resolve before acting:**

1. **Production is not actually running `main`.** Per `HANDOFF-status-2026-05-29.md`, the live *backend* is running a `develop` commit (`421502e`), and `main` is ~154 commits behind. So "match `main`" makes staging match the **intended** production baseline, which may differ slightly from what the live server runs today. Confirm Achia is OK targeting `main` as the baseline (recommended — `main` is the sacred reference), or whether she wants to first reconcile what production runs.
2. **Backend ↔ database coupling.** If backend code/migrations roll back to `main`, the **staging database** (`reacti_staging`) must be rebuilt to `main`'s schema and re-seeded, or the app will hit shape mismatches. Plan for a clean staging DB rebuild + re-run `StagingTestAccountsSeeder`.

If Achia only wants the **iOS app** reset (not the backend), that's a valid narrower scope — but flag that identical app code against a *different* backend can still behave differently, so the backend should at least be confirmed contract-compatible (run the Phase 3d contract tests).

---

## 3. KEEP vs RESET (the precise spec)

### KEEP on `develop` (do NOT roll back) — infrastructure, tests, build/deploy, docs. These are behavior-neutral for a production build.

- `/.github/workflows/**` — all CI and deploy workflows, including `ios-testflight.yml`, `staging-deploy.yml`, `migration-tests.yml`, `contract-tests.yml`, `backend-ci.yml`, `post-deploy-smoke.yml`, `enforce-main-source-branch.yml`, `deploy-dashboard.yml`.
- `/backend/tests/**` — unit, feature, contract (`backend/tests/Contract/`), smoke, migration tests.
- `/backend/database/seeders/StagingTestAccountsSeeder.php` and any seeding config it relies on (`config/seeding.php` / `STAGING_SEED_PASSWORD`).
- iOS **staging flavor / build config** (behavior-neutral; only adds a side-by-side staging identity):
  - `app/ios/Flutter/AppIdentity.xcconfig`, `app/ios/Flutter/FlavorOverride.staging.xcconfig`
  - `app/ios/ExportOptions-staging.plist`
  - the `AppIconStaging.appiconset/` staging icon set
  - the variable-ization of `PRODUCT_BUNDLE_IDENTIFIER` / `ASSETCATALOG_COMPILER_APPICON_NAME` in `app/ios/Runner.xcodeproj/project.pbxproj` and the `$(APP_DISPLAY_NAME)` keys in `app/ios/Runner/Info.plist`, plus the `app/ios/.gitignore` entry, the `Debug.xcconfig`/`Release.xcconfig` includes.
  - **`app/lib/networks/endpoints.dart` build-time `BASE_URL` switch** — KEEP. It defaults to production, so it does not change production behavior; it is what lets the staging build point at staging.
- `/docs/**`, `CLAUDE.md`, `.gitattributes`, `.gitignore`, and the dependency-audit / `composer.json` reconstruction work (Phase 3i) — keep.

> Rule of thumb for KEEP: "Does this change how the app behaves for a normal production user?" If **no** (it's tests, CI, build config, staging identity, docs), keep it.

### RESET to `main` (roll back) — application behavior.

- `app/lib/**` — **except** the single `BASE_URL` build-time line in `endpoints.dart` noted above. (This is where the private-chat regression lives, e.g. `app/lib/features/chat/presentation/inbox_screen.dart`.)
- `backend/app/**`, `backend/routes/**` — application logic and API behavior.
- `backend/database/migrations/**` that change schema/behavior vs `main` — reset (and rebuild the staging DB accordingly). Be careful and deliberate here; coordinate with the staging DB rebuild.
- Any other file whose change alters runtime behavior.

> When KEEP vs RESET is ambiguous for a specific file, **default to RESET** (match `main`) and note it, so the baseline is genuinely `main`-equal. Refinements come back in the staged rebuild.

---

## 4. Preserve everything first (nothing is lost)

Before touching `develop`:

1. Create and push an archive branch of the current tip:
   `archive/develop-snapshot-2026-05-30` → push to `origin`.
2. Create and push a tag for good measure: `tag develop-pre-reset-2026-05-30` → push.
3. Confirm both exist on GitHub.

All 154 commits of refactor work remain fully recoverable from the archive branch/tag. The staged rebuild (Section 6) can cherry-pick or reference them.

---

## 5. Building the new baseline (recommended git strategy)

Prefer the **additive-from-main** approach (easier to reason about than reverting in place):

1. Start a working branch from `main`.
2. Bring over **only the KEEP list** from the archived `develop` snapshot, e.g. `git checkout archive/develop-snapshot-2026-05-30 -- <each KEEP path>`, review, and commit in a few logical commits (Conventional Commits, e.g. `chore(baseline): re-apply CI/test/staging infra on a main-equal base`).
3. The result is: **application code == `main`**, plus all testing/staging scaffolding.
4. Make `develop` point at this new baseline. Because `develop` is a protected, shared branch, do this carefully and with Achia's explicit go-ahead — options: a single reviewed PR that replaces the tree, or a controlled force-update (admin) after the archive is confirmed pushed. **PAUSE for Achia before any force-update.**
5. Trigger `staging-deploy` (backend) and the `ios-testflight.yml` build, rebuild the staging DB to `main`'s schema, and re-seed test accounts.

### Verify the baseline (the whole point)
- Build staging (`develop`) and confirm the app behaves like production (`main`): open the **private chat** as `smoke-a` ↔ `smoke-b` — it must render correctly (the black screen is gone because the regression was rolled back). Group chat still works.
- Ideally compare against the live production app side by side: same screens, same behavior.
- All CI green; contract tests pass against the staging backend.

When Achia confirms both apps look the same, the baseline is established.

---

## 6. Rebuild forward — slow, verifiable stages

Re-introduce the set-aside improvements in this order. **Every change is a small branch → PR to `develop` → squash-merge (Conventional Commits) → re-verified on the staging TestFlight build before the next.** Reference `archive/develop-snapshot-2026-05-30` and `docs/refactor/big-refactor-plan.md` for the prior work.

- **Stage 1 — Comments & docstrings only.** No logic changes whatsoever. Pure documentation of the existing (now `main`-equal) code. Easy to review; zero behavior risk.
- **Stage 2 — Refactor (behavior-preserving).** Conventions, renames, structure (the `R0–R10` work in `big-refactor-plan.md`). No functional change — tests + staging must show identical behavior after each step.
- **Stage 3 — Improve the real code.** Deliberate, reviewed behavior changes/fixes. This is where any genuine fix (and re-doing whatever the refactor was trying to achieve) lands — one focused change at a time, each verified on staging.
- **Stage 4 — New features / functionality.** Only after the codebase is healthy and proven.

**Gate between stages:** all required tests green AND Achia confirms on the staging TestFlight build before promoting `develop → main`.

---

## 7. Guardrails (from `CLAUDE.md` — non-negotiable)

- **Do NOT break the patent flow** — silent front-camera recording when a recipient opens a media message (`app/lib/features/chat/presentation/widget/receiver_message_widget.dart`, `recordVideoSilently()` via `_buildBlurPlaceholder()` after `mark-viewed`). Keep/restore its end-to-end regression test.
- **`main` is sacred; do NOT touch production.** All work via branches/PRs to `develop`, squash-merge. Reaching `main` only happens through the promotion gate after staging verification.
- **Preserve before destroying** — the archive branch + tag must be pushed and confirmed before `develop` is rewritten.
- **Pause for Achia** on: confirming the Section 2 assumptions, and any force-update/rewrite of the shared `develop` branch.

---

## 8. One-line summary

Archive the current `develop`, rebuild `develop` so the **app code equals `main`** (fixing the staging-only regressions) while **keeping all tests, CI, and the staging/TestFlight pipeline**, prove the staging and production apps are identical, then re-introduce improvements in four verified stages: docstrings → refactor → code improvements → features.
