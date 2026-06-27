# Runbook — first production release of the new Reacti app (2026-06-12)

**Goal:** ship the verified release candidate (`release/first-app`, staging build
1020 — the rebuilt app + Phase A/B security + the composer fix, **no consent
flow**) to the App Store and production backend, **carefully, in order, with
rollback ready.**

This is the highest-risk step in the project — a production backend change once
broke the live app. Go slowly, verify at each gate, and never skip a checkpoint.

## Who does what

- **Claude Code** — git/branch mechanics, opening PRs, running CI, building the
  iOS release artifact. Does **not** approve prod gates or submit to the App Store.
- **Achia** — approves the `develop→main` PR (CODEOWNERS), the App Store
  submission, and the `production` deploy gate. Owns the version number.
- **Operator** — the VPS: deploy-path health, the rollback snapshot, running the
  backend deploy, and the on-server checks. Owns anything touching the prod server.

## What's actually live right now — verify, don't assume (prod ≠ main)

Before anything, the operator confirms the true production state, because "main =
production" has not always held here:

- [ ] App Store app version currently live (expected **v1.0.9**).
- [ ] The **commit** the production *backend* is actually running (history shows
      prod has run a `develop` incident-recovery commit, not `main`).
- [ ] `backwards-compat.yml` is **green on the candidate** and genuinely exercises
      the live v1.0.9 app's expected API shapes (this is the guard that lets a new
      backend stay safe for the old app — the whole release order depends on it).

---

## Phase 0 — Pre-flight gates (ALL must pass before touching production)

- [ ] **Release candidate verified on staging.** Build 1020 tested on-device by
      Achia — composer fix + core flows + recording loop. ✅ (done)
- [ ] **Make `develop` equal the release candidate** so promotion respects the
      "only `develop` merges to `main`" rule (do **not** disable that guardrail).
      *Claude Code:* preserve the consent work on a branch
      (`feature/dg1-consent`), then revert the DG1 consent commits (#161–164) off
      `develop` so `develop` content == `release/first-app`. Confirm: no
      `app/lib/features/consent/`, no `[[CONSENT_COPY_PENDING_LAWYER]]`, test count
      back to 612, `flutter analyze` clean. The consent work is **not lost** — it
      waits on its branch for a later release (once the lawyer's copy is in).
- [ ] **All required checks green on `develop`**: "PHP Tests", "Analyze & Test",
      contract-tests, migration-tests, backwards-compat.
- [ ] **Deploy path is healthy.** *Operator:* run `prod-deploy-check.yml`
      (read-only SSH check). It must pass — if it fails, the GitHub-runner IP is
      likely still rate-blocked by Hostinger; **stop**, wait for cooldown or use a
      self-hosted runner. Do **not** retry in a tight loop (each attempt
      re-extends the block).
- [ ] **Fresh rollback snapshot exists.** *Operator:* confirm a current VPS
      snapshot taken **now**, pre-deploy. ⚠️ Hostinger keeps only **one** snapshot
      slot — taking a new one **overwrites** the previous; make sure you're not
      destroying a rollback point you still want. This snapshot is the undo button.
- [ ] **Decide the version number.** *Achia:* bump `app/pubspec.yaml` from
      `1.0.9+10` to the release version (e.g. `1.1.0+11`). The git tag must match.

---

## Phase 1 — Promote to `main` (code only — nothing deploys yet)

1. *Claude Code:* open the **`develop → main`** PR. It passes
   `enforce-main-source-branch` because the source is `develop`. Title it as the
   release; list exactly what's in it (security batch + composer fix; consent
   deferred).
2. *Achia:* review and approve (CODEOWNERS requires it). Merge.
3. ⚠️ **Merging to `main` auto-queues `backend-deploy.yml`** (it triggers on push
   to `main`) — but it **pauses on the `production` Environment approval gate with
   Achia as required reviewer. DO NOT approve it yet.** Merging does **not** build
   or release the app (the app builds only on a `v*` tag). So at this point:
   nothing is in front of users; a backend deploy is *waiting* for an explicit
   approval that we give later, in order.

---

## Phase 2 — The release-order decision (the critical one)

The old rule was **app-first**, because a new backend used to break the old app
(the `is_viewed` incident). That failure mode is now guarded by
`backwards-compat.yml` + contract tests. So the order that is actually safest for
shipping a *new app that needs the new backend* is:

**Recommended — backend-first, with the old app as the canary:**

1. Operator approves/runs the **backend deploy** to production (the queued
   `backend-deploy.yml`). Migrations run.
2. **Immediately verify the OLD live v1.0.9 app still works** against the new
   production backend (log in, open a chat, send, the recording loop). This is the
   canary: if backward-compat holds (it should — it's tested), the old app keeps
   working and all existing users are unaffected.
3. **If the old app is fine →** proceed to release the new app (Phase 3). New-app
   users then land on a backend that already supports them.
4. **If the old app breaks →** roll back immediately (restore the snapshot) and
   stop. Do **not** release the new app. This is exactly why backend goes first
   here: you find out *before* any user is forced onto new code.

> Why not strict app-first? If the app ships first while prod still runs the old
> backend, new-app early adopters hit a backend missing the new endpoints and the
> *new* app breaks for them. Backend-first (with a backward-compatible, tested
> backend and the old-app canary check) protects both populations. **If the
> operator is not fully confident backwards-compat genuinely covers the live app,
> keep app-first instead and accept the new-app-on-old-backend gap — but then the
> backend deploy must follow within minutes of the app going live.** Operator +
> Achia make this call together, eyes open.

---

## Phase 3 — Release the new app to the App Store

1. *Claude Code/Achia:* push the **`v1.x.x` tag** on `main` (matches the pubspec
   bump). This triggers `ios-release.yml` → builds the production IPA
   (`API_BASE_URL=https://reacti.io`) → uploads to App Store Connect.
2. *Achia:* in App Store Connect, submit the build for review, then release
   (phased release is fine — it rolls out gradually and is pausable).
3. Apple review takes time (hours–days). Nothing is live until you release it.

---

## Phase 4 — Post-release verification

- [ ] *Achia:* once the app is live, install the **production** app from the App
      Store (not TestFlight) and re-run the core checklist on prod: composer fix,
      send text/image, group, recording loop, login persistence.
- [ ] *Operator:* watch server logs/error rates for the first hours; confirm
      `post-deploy-smoke` (if wired) is green against prod.
- [ ] Confirm both old-app users (mid-rollout) and new-app users are healthy.
- [ ] Update `PROGRESS.md`: mark the release shipped, date it, list what went out.

## Rollback plan (if anything goes wrong)

- **Backend bad:** operator restores the pre-deploy VPS snapshot (the one slot).
- **App bad but backend fine:** pause/halt the phased App Store rollout; ship a
  fix forward (you can't "unpublish" a build, but phased release limits blast
  radius).
- **Tag/build wrong:** delete the bad `v*` tag, fix, re-tag.
- Keep the consent branch and `release/first-app` intact until the release is
  confirmed stable.

## Lessons baked in (don't violate these)

- **Respect `develop`-only-to-`main`.** We made `develop` the candidate instead of
  bypassing the rule. If any branch protection is ever touched to land something,
  **re-enable it immediately** (a disabled ruleset was forgotten once).
- **One snapshot slot** — never overwrite a rollback point you still need.
- **Don't hammer CI→prod SSH** — a burst re-triggers Hostinger's rate-block; if
  `prod-deploy-check` fails, wait/cooldown, don't loop.
- **prod ≠ main** — verify what's actually deployed; don't assume.
- **Achia owns** the prod gates, the App Store submission, and the version.
  **Claude Code never** approves prod or submits to Apple.
- **Phased App Store rollout** limits blast radius — prefer it for a first release.

---

## Immediate next action

Phase 0, step 2: have **Claude Code lift the consent work off `develop`** (onto
`feature/dg1-consent`) so `develop` becomes the clean release candidate, then
confirm all required checks — including `backwards-compat` — are green. In
parallel, the **operator** runs `prod-deploy-check.yml` and confirms a fresh
rollback snapshot. Nothing touches production until every Phase 0 box is ticked.
