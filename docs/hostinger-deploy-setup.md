# Hostinger deploy + smoke-test setup

This document covers everything you need to make `main` flow safely to
the Hostinger-hosted backend at `reacti.io` and be functionally
verified there, *before* you ship the matching iOS build to the App
Store.

It's structured as:

1. Confirm Hostinger access type (see hPanel checklist below).
2. Create test users for the smoke suite.
3. Add GitHub Actions secrets.
4. (After step 1 confirms) the deploy workflow lands and you wire the
   approval gate.

---

## Step 1 — hPanel checklist (paste the answers back)

Log in at https://hpanel.hostinger.com → your hosting plan. Find each
of these and tell me the result. I'll write the deploy workflow
specifically for what you have.

### A. SSH (preferred)

`hPanel → Advanced → SSH Access`. If the tile exists and is enabled:

- **Hostname** (e.g. `XXX.hostinger.com` or your domain)
- **SSH port** (Hostinger commonly uses **65002**, not 22)
- **Username** (typically `u<number>`)

If SSH is *Disabled*, click **Enable** if your plan allows it.
Hostinger Business / Cloud / Premium plans usually have SSH; the
older Single plan does not.

### B. Git deployment

`hPanel → Files → Git`. If a tile is there:

- Note that it exists. We can use it as a fallback or as a simpler
  primary path.

### C. The Laravel root path

`hPanel → Files → File Manager`. Navigate to where `artisan` lives.
Typical layout:

```
/home/u<NUMBER>/domains/reacti.io/public_html/backend     ← `artisan` here
                                  /public_html             ← `public/index.php` here, symlinked or copied from backend/public
```

Note **the path that contains `artisan`** — that's what the deploy
script `cd`s into.

### D. Plan name

Just the plan name (Business / Cloud / Premium / Single).

### E. Database access

`hPanel → Databases → MySQL Databases`. Confirm one exists named
something like `u<NUMBER>_reacti`. The deploy workflow doesn't need
direct DB access — `php artisan migrate` runs over SSH on the
server, which uses the local credentials from `.env` — but worth
knowing the DB exists and is reachable.

### F. Cron Jobs (Plan B if no SSH)

`hPanel → Advanced → Cron Jobs`. Confirm the tile exists. If we can't
SSH, the fallback is to drop a "deploy hook" script in `public_html`
and have a cron run it after git pulls — clunkier but workable.

Reply with: SSH yes/no + port, Git tile yes/no, Laravel root path,
plan name. With that I'll write the deploy workflow specifically for
your setup.

---

## Step 2 — Create dedicated smoke-test users on Hostinger

The smoke suite (`backend/tests/Smoke/SmokeTest.php`) hits the *live*
backend with two test accounts:

- **User A** — `smoke-a@reacti.test` (or any unused email you control)
- **User B** — `smoke-b@reacti.test`

They should be **dedicated** — don't reuse real users. Both should
be **active** (no OTP-pending state), **friends with each other**,
and **members of one shared group**. Idempotent assertions assume
those preconditions are true and don't re-create them.

To set them up, on the prod backend create both via the normal
registration flow (verify the OTP from your email or directly via the
DB), then connect them as friends, then add both to one group. Record
the **group's id** — you'll need it as `SMOKE_GROUP_ID` below.

---

## Step 3 — GitHub Actions secrets for the smoke workflow

At `https://github.com/reacti25/reacti/settings/secrets/actions`,
add:

| Secret | Value |
|---|---|
| `SMOKE_USER_A_EMAIL` | A's email |
| `SMOKE_USER_A_PASSWORD` | A's password |
| `SMOKE_USER_B_EMAIL` | B's email |
| `SMOKE_USER_B_PASSWORD` | B's password |
| `SMOKE_GROUP_ID` | The id of the shared group both A and B belong to (optional — that one test skips if absent) |

Once they're in, you can run the smoke workflow manually now (before
the deploy workflow even exists) to confirm the suite is wired
correctly against `https://reacti.io/api`:

- Open GitHub → Actions → **Post-deploy Smoke Tests** → **Run workflow**.
- Leave the `base_url` field as `https://reacti.io/api`.
- Click Run.

If the suite passes — you've verified the smoke harness works against
your real backend before the deploy pipeline is even built.

---

## Step 4 — (after step 1 answered) Deploy workflow + approval gate

The deploy workflow (`.github/workflows/backend-deploy.yml`) is not
committed yet — it depends on your hPanel access type from step 1.
Once you reply with that info I'll write it. Then the flow becomes:

1. Push to `main`.
2. GitHub Actions waits at a **required-reviewer gate** (your account
   approves with one click in the Actions UI). This is the
   "I'm about to deploy to production" sanity step that protects
   against accidental main merges.
3. Approve → deploy runs (`cd backend && git pull && composer install
   --no-dev && php artisan migrate --force && php artisan optimize
   && php artisan queue:restart`).
4. Post-deploy smoke workflow runs automatically against the live
   URL.
5. If smoke is green you tag `v1.0.10` to trigger the iOS release
   pipeline → TestFlight → install on iPhone → promote to App Store.

The approval-gate part is a GitHub **Environment** with required
reviewers — I'll wire that when the deploy workflow lands. Right now
it can't be added (an environment must be referenced by at least one
workflow that uses it).

---

## What's currently in place

- ✅ `backend/tests/Smoke/SmokeTest.php` — the smoke suite.
- ✅ `backend/phpunit-smoke.xml` — separate config so smoke doesn't
  run in the normal `php artisan test`.
- ✅ `.github/workflows/post-deploy-smoke.yml` — runs the suite on
  `workflow_dispatch`; will be triggered by the deploy workflow once
  that lands.
- ⏳ `.github/workflows/backend-deploy.yml` — pending your hPanel
  access info.

## What's NOT in place (decisions noted)

- **No staging environment.** You chose prod-direct + approval gate.
  Smoke tests run against prod after deploy; an approval gate
  protects against accidental pushes to `main` becoming a live
  deploy.
- **No DB backup automation in the deploy.** A naive Laravel-migrate
  on prod has no rollback. Worth adding a `mysqldump` step to the
  deploy workflow before `migrate --force` — happy to do that as
  part of step 4.

---

## Troubleshooting (will grow over time)

(Reserved — populated when the deploy workflow lands.)
