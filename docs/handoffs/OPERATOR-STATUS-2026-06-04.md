# Operator status note → Claude Code (2026-06-04, evening)

## ⛔ UPDATE — production backend deploys are FROZEN (incident + lesson)

A backend deploy to production **broke the live app** and was **rolled back**
(VPS snapshot restore). Root cause: the production iOS app on the App Store is
the **OLD** app; deploying the new backend changed response formats the old app
can't read → black chat screen (the documented `is_viewed` bool-vs-int bug).
Staging was fine because the Staging app is the NEW app.

**Lesson / new rule — the app and backend must move together, app first:**
1. **Do NOT deploy the new backend to production** (do not approve the Backend
   Deploy production gate) until the **new iOS app is released to the App Store
   and adopted**. The correct order is **App Store release FIRST, backend
   second.**
2. Merging `develop`→`main` is fine (code only) — but the **production deploy
   gate stays UNAPPROVED** until the app is live. The operator owns that gate.
3. Keep doing all your work on `develop`/staging as normal. This freeze is only
   about the production *backend* deploy step.

## 🔁 Cadence update — run continuously, stop only at a RELEASE MILESTONE

This **supersedes** the "stop after every big step" rule in the handoff. Reason:
production updates are now **batched** (app-first App-Store release, then backend
— see freeze above), so you do NOT need to stop and wait after each big step.

**New cadence:**
- **Keep flowing** through the plan's big steps on `develop`/staging — small,
  self-reviewed PRs, merged to `develop` when green. Don't stop to ask after
  each one. Keep `develop` and `main` in sync (code only; the prod *deploy* stays
  frozen).
- Maintain a **"Next release — what's in it"** running list in `PROGRESS.md`:
  every user-facing change and security fix accumulating since the last release,
  in plain language Achia can read.
- **STOP and signal a RELEASE MILESTONE** when the batch is worth shipping to
  real users — i.e. it contains **user-meaningful** improvements, not just
  internal/CI/refactor work. **The next planned milestone is when Stage 4c
  (correctness bug fixes) is complete** and green on staging (so the batch =
  security 4a/4b + patent 4d + correctness 4c = safer *and* visibly better).
  Pure internal batches (CI, refactor, docs) are **not** release triggers on
  their own.
- At a milestone: write a clear **`🚀 RELEASE MILESTONE`** entry in `PROGRESS.md`
  — what's in it (user-facing + security), confirmed green on staging — and tell
  Achia: **time for an App Store release (app first), then the operator deploys
  the backend.** Then **wait** for her to drive the release before continuing.
- You do **not** run the release yourself: tagging/releasing the iOS app and
  approving the backend deploy are Achia + operator steps.

---


From the Cowork (operator) session. Quick state so you're in sync. **None of
this changes your job** — keep executing the master plan on `develop`/staging in
checkpoint mode (`HANDOFF-execute-master-plan-2026-06-04.md`). This is FYI +
one "don't do" below.

## Branch baseline
- `develop` and `main` hold the **same good, verified version** — that's your
  start line. The "roll develop back to the old version" idea Achia floated is
  **on hold / not happening** unless she explicitly says so. Build forward on
  `develop`.

## Production deploy — investigated, currently parked (not your concern)
The `develop→main` promotion completed at the branch level, but the **backend
deploy to the production server is blocked**, and we've now diagnosed it:

- Server is healthy and SSH (port 22) is reachable from the open internet —
  confirmed by `Test-NetConnection 72.61.202.136 -Port 22` → `TcpTestSucceeded:
  True` from Achia's laptop. ufw allows 22, fail2ban shows 0 bans, and there is
  **no Hostinger network firewall** configured.
- The timeouts are **specific to GitHub Actions runner IPs**: a burst of ~6
  rapid SSH attempts from GitHub tripped **Hostinger's automatic edge/abuse
  protection**, which is now dropping GitHub's IP range (normal IPs still get
  through). It typically clears after a cooldown.
- Plan: let it cool, retry the deploy once at the **first real promotion
  checkpoint** (after Achia verifies a batch on staging/TestFlight). If still
  blocked then, the durable fix is a **self-hosted GitHub runner on the VPS**
  (deploy runs locally, no inbound connection to block) or a Hostinger support
  request — the operator handles that.

### ⚠️ One thing NOT to do
- **Do not attempt any production deploy, and do not open SSH/`prod-deploy-check`
  connections from CI to the production server.** Every extra GitHub→server
  connection right now risks **re-extending the rate-block**. Leave the prod
  server alone; it's the operator's lane. (Staging deploys from `develop` are
  fine and expected — those go to the staging user/site, unaffected.)

## Reminders that still hold
- **Checkpoint cadence:** finish one big step → green on `develop`/staging →
  write a `CHECKPOINT` in `PROGRESS.md` → **stop and wait** for Achia.
- **Dependency Audit** stays intentionally RED (deferred CVE-2026-48019; needs
  a major Laravel upgrade — its own future project, not routine work).
- A fresh VPS **snapshot** exists (2026-06-04 20:22) as a rollback point.
- Park legal/product decisions in `NEEDS-ACHIA.md`; never promote to `main`,
  deploy to prod, or touch the App Store without Achia.

Carry on with the current big step (you were mid Stage 4a / EP1 security
criticals). Thanks.
