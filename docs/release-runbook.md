# Release runbook

How a change goes from `develop` to real users, and the gates along the way.
Read alongside `.claude/skills/clean-code-standards/SKILL.md` (Part 2) and
`NEEDS-ACHIA.md` (open gates).

## Golden rule — app first, then backend

The App Store app is the **OLD** app. Deploying a new backend to it once broke
the live app (a response-shape change it couldn't read). So:

1. Release the new iOS app to the App Store (Achia drives) and let it adopt.
2. **Then** the operator approves the production **Backend Deploy** gate.

Merging `develop`→`main` is code-only and fine anytime; the production Backend
Deploy gate stays **UNAPPROVED** until the new app is live. Never trigger a prod
deploy or open a CI→prod SSH connection outside that flow.

## Staging — continuous validation off `develop`

Every push to `develop` runs **Staging Deploy** (`staging-deploy.yml`) →
`staging.reacti.io`, then the **Post-deploy Smoke Tests**
(`post-deploy-smoke.yml`) run against staging via a `workflow_run` chain (B2).

The smoke suite (`backend/tests/Smoke/`, 9 steps) exercises the load-bearing
paths end-to-end: health-check, A/B login, profile, combined chat list, friends
list, group list, group inbox, and the **patent-flow send → mark-viewed**.

- **A RED post-deploy smoke BLOCKS a promotion recommendation.** Do not advise
  promoting `develop`→`main` (or signal a release milestone) while the latest
  staging smoke is red. Investigate first.
- **Self-gating:** the suite **skips** (does not fail) when the `SMOKE_*`
  secrets are unset — the health check still runs; the login-dependent steps
  skip. To activate full staging validation, the operator sets the `SMOKE_*`
  secrets to the **staging seed accounts** (`smoke-a@reacti.test` /
  `smoke-b@reacti.test`, `STAGING_SEED_PASSWORD`, and the staging
  `SMOKE_GROUP_ID`). Until then the smoke is green-but-partial. See
  `NEEDS-ACHIA.md`.
- **On-device:** the automated smoke is HTTP-level. The full patent loop on a
  real device (silent recording → reaction upload → unblur) is confirmed by
  Achia on the Reacti **Staging TestFlight** build (amber icon,
  `com.reacti.app.staging`). Any app-code change warrants a fresh staging build.

## Required status checks on `main`

These must be green to merge into `main`. Keep `backend-ci.yml` /
`flutter-ci.yml` filter-free so the required checks always report (a required
check with a `paths:` filter deadlocks a PR that doesn't touch that path).

Currently required:

- **PHP Tests** (`backend-ci.yml`)
- **Analyze & Test** (`flutter-ci.yml`)

Candidates to promote to required once each is stably green (tracked under
**C4**, applied by the operator in the `protect-main` ruleset — confirm both the
classic *Branch protection* and *Rulesets* systems agree):

- Contract Tests, Migration Tests
- Backwards Compatibility (**A1**) — only after the new app ships and the tag is
  re-pinned (it is intentionally a no-op until then)
- iOS Integration (**B1**) — once it exists and is stable

## Promotion checklist (`develop` → `main`)

1. Latest staging smoke is **green** (not red, not a stale skip you're relying on).
2. Required checks green on the promotion PR.
3. The batch is genuinely release-worthy (user-meaningful or security), and no
   release-blocking gate is open (e.g. **DG1** consent flow — see `NEEDS-ACHIA.md`).
4. Tag the release on `main` (`vX.Y.Z`); update `CHANGELOG.md`.
5. App first: Achia releases the iOS app; **only after it is live** does the
   operator approve the production Backend Deploy.
