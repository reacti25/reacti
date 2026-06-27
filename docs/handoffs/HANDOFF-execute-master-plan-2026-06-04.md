# Handoff — Claude Code: execute the hardening master plan autonomously

**Date:** 2026-06-04
**To:** a Claude Code session working in this repo (`reacti25/reacti`).
**From:** the Cowork (operator) session + Achia.
**Operator:** Achia — non-developer, owner. Work **continuously *within* a big
step without asking permission for routine engineering decisions — but STOP at
the end of each big step** (see §4) so she can test it on staging and promote it
to `main`/the real app before you start the next one. Honor the hard guardrails
in §4.

---

## 1. Your goal

Execute **`docs/MASTER-PLAN-app-hardening-2026-06-04.md`** make Reacti
well-tested, well-documented, secure, correct, and clean — *then* it's ready for
new features. Work the plan **in order, one big step at a time**, as many small
PRs as each big step takes — then **stop and hand back to Achia** at the
checkpoint (§4) before starting the next big step.

## 2. Read these first, in this order

1. `CLAUDE.md` (root) — repo rules; **the patent flow is load-bearing**.
2. `docs/MASTER-PLAN-app-hardening-2026-06-04.md` — the roadmap you execute.
3. `docs/code-quality-backlog.md` — every known problem, by severity.
4. `docs/enhancement-plan.md` — the behaviour-changing phases (EP0–EP11) + the
   decision gates (DG1–DG8). The master plan's Stage 4 maps to these.
5. `docs/conventions.md` — style + Conventional Commits.
6. `docs/testing/HOW-TO.md` + `docs/testing/inventory.md` — how/what to test.

## 3. Current state (start line)

- **Branches:** `develop` and `main` currently hold the **same good, verified
  version** (the develop→main promotion was completed at the branch level).
  Treat `develop` as the working baseline and build on it. *(A "roll develop
  back to the old version" idea was floated by Achia and is on hold — do NOT
  act on it unless she explicitly says so.)*
- **Production server + App Store app are still the OLD version** — the prod
  backend deploy is **paused/blocked** on a Hostinger network-connection issue,
  handled separately by Achia + the Cowork operator. **Not your concern** — do
  not attempt production deploys.
- **CI:** required checks are green on `develop`. The **Dependency Audit** job
  is **intentionally RED** — it surfaces deferred **CVE-2026-48019** (Laravel
  CRLF; all of Laravel 11.x affected, fix needs a major-version upgrade). It is
  **non-required**; leave it red. The solver block is suppressed via
  `config.policy.advisories.block:false` in `backend/composer.json`. The full
  Laravel security upgrade is its own future project — do not attempt it as part
  of routine work.
- **Test suites exist** (~80 Flutter, ~55 backend) but coverage is uneven; the
  **patent-flow integration harness is missing** (Stage 1 / EP4 builds it).
- A leftover cleanup: the `|| true` ssh-keyscan fix is on `backend-deploy.yml`
  (develop+main) but **not yet on `prod-deploy-check.yml`** on develop — fold it
  in when you touch CI (Stage 0).

## 4. Autonomy contract — how to run without delaying Achia

**DO autonomously, no permission needed:**
- Branch off `develop` (`test/*`, `docs/*`, `enhance/epN-*`), test-first, make
  the change, run the suites, open a PR into `develop`.
- **Self-review every PR** before merging: run the `security-review` skill (and
  `review`) as your verification step; fix what they flag.
- When the **required** checks are green and your self-review passes, **merge
  the PR into `develop`** and move straight to the next item *within the current
  big step*. (Merging to develop auto-deploys the backend to staging — fine and
  intended.)
- Make sensible engineering choices and keep moving. Don't stop to ask about
  routine decisions — decide, document the reasoning in the PR, proceed.

**STOP at the end of each BIG STEP (checkpoint — this is the key cadence):**
- A **big step** = one numbered stage or sub-stage of the master plan
  (Stage 0; the 4a CRITICALs; Stage 1; Stage 2; then 4b, 4c, 4d, … each
  separately). It is several PRs, all merged to `develop` and green.
- When a big step is **complete and green on `develop`/staging, STOP.** Do NOT
  start the next big step.
- Write a **`CHECKPOINT`** entry in `PROGRESS.md`: what changed, exactly what
  Achia should test on the Staging app, and note it's ready for her TestFlight
  check + a `develop`→`main` promotion. If the step changed Flutter/app code,
  say so (she needs a fresh staging TestFlight build to see app-side changes).
- Then **wait.** Resume with the next big step only after Achia explicitly says
  to continue (she'll have tested staging and promoted to `main`/the real app
  first).
- **Where you are right now:** Stage 0 is done and you are **mid Stage 4a (EP1
  security criticals)**. Apply this cadence from here: **finish the remaining 4a
  items** (e.g. migrate the auth token to `flutter_secure_storage`), get them
  green on `develop`, then **STOP at the 4a checkpoint** and hand back to Achia.

**PARK, don't block (this is how you avoid being delayed):**
- For **decision gates DG1–DG8** (legal/product/business calls), do NOT wait.
  **Skip that single item**, append it to a running **`NEEDS-ACHIA.md`** at the
  repo root (what's needed + why), and continue with everything else.
- If any one item is blocked, pick the next unblocked item. Only stop entirely
  if *nothing* in the plan can proceed.

**NEVER without Achia's explicit approval:**
- Merge/promote `develop` → `main`.
- Deploy to production, run anything against the production server/DB, or touch
  the live App Store build.
- Weaken security/TLS in production, or commit secrets / service-account keys.
- Force-push or rewrite history on `main`.
- Touch the **patent flow** code (`send` / `mark-viewed` / blur flags /
  `recordVideoSilently`) **until the Stage 1 integration harness is green** —
  then you may, re-running the patent suites on every related PR.

## 5. Order of attack (from the master plan)

1. **Stage 0 — CI/test gates** (EP0): always-report required checks, PHPStan/
   Larastan baseline, `dart format`/analyze gates, native build job, coverage
   reporting, `composer audit` + Dependabot. (Fold in the `prod-deploy-check.yml`
   ssh-keyscan cleanup here.)
2. **Pull forward the Stage 4a security CRITICALs** (EP1) — exploitable today:
   delete the unauthenticated `routes/web.php` maintenance routes
   (`/run-migrate-fresh` can drop the DB), add auth/OTP rate-limiting, stop
   returning OTP in responses, remove the `MyHttpOverrides` TLS bypass, fix
   token storage/erase-on-logout. Each test-first.
3. **Stage 1 — patent-flow integration harness** + broaden the test net on the
   risky paths; set and ratchet a coverage floor.
4. **Stage 2 — docstrings everywhere** + `docs/architecture.md` + API spec.
5. **Stage 3 — safe-refactor leftovers only** (mostly already done — don't redo).
6. **Stage 4b → 4k** in order (security hardening → correctness → patent-flow
   hardening → DB → API → backend arch → app arch → performance → UX → cleanup).
7. **Stage 5 — features** only after the above.

## 6. Keep Achia in the loop without blocking her

- Maintain **`NEEDS-ACHIA.md`** (decisions/gates you parked) and a short
  **`PROGRESS.md`** (what you've merged into develop, what's next) at the repo
  root, so she and the operator can see status at a glance and approve the
  `develop`→`main` promotions in batches when she's ready.
- At **every big-step checkpoint** (§4), `PROGRESS.md` must clearly say staging
  is ready for her TestFlight check + a `develop`→`main` promotion, and you wait.

Start now: read §2, then begin Stage 0.
