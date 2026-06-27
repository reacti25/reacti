# Handoff — promote verified `develop` to production (and finish the deploy-key fix)

**Date:** 2026-06-04
**Operator:** Achia (non-developer; keep explanations short, beginner-friendly, one concrete action at a time, give clear recommendations, pause before anything destructive or production-touching).
**For:** a fresh Claude Code session continuing this work with Achia.
**Repo:** `C:\Users\Achia\reacti` (monorepo: `app/` = Flutter iOS app, `backend/` = Laravel 11 API).

---

## 1. TL;DR — where we are

The whole staging chat is now **working and verified on-device**, and `develop` is the **good, working baseline**. The goal now is to **promote `develop` to production** so the real App Store "Reacti" app behaves the same as the "Reacti Staging" app — one clean baseline to build future features on.

**We are on Step 1 of the promotion: verifying/fixing the production deploy path — and it is currently BLOCKED on one small thing** (installing a new SSH key on the production server; the terminal keeps mangling the long key on paste). Details + exact steps in §3.

**Do NOT deploy anything to production until Step 1 is green and Achia approves each production step.** `main` is sacred.

---

## 2. What's already done (verified)

- **Private chat fully works on staging** (build 1011, two real iPhones): renders, sends, images display, media arrives **sealed**, tap-to-open unblurs, and the **silent reaction recording fires** (the patent flow). ✅
- **Three root-cause bugs found + fixed + merged to `develop`** (all the same family: backend sends `true`/`false`, old app code checked `1`/`0`):
  1. **Black screen** — `is_viewed` typed `int?` in the app; widened to `dynamic` (was develop PR #113, already in develop).
  2. **Image not displaying** — conversation endpoint returned a *relative* `file` path; wrapped in `asset()` → absolute URL. (PR #115, merged)
  3. **Media not sealed / no reaction** — app checked `data.isBlurred == 1` but API sends bool `true`; extracted `isMediaSealed()` accepting both. (PR #117, merged)
- **iOS TestFlight build-delivery fixes** merged (PR #116): auto-increment build number (`1000 + run_number`) + `ITSAppUsesNonExemptEncryption=false` (so builds clear export compliance and install).
- The earlier "reset `develop` back to `main`" idea was **abandoned** — we proved `main` is the *older, buggier, less-secure* version (missing 22 fixes incl. security ones). `develop` is the good version. The old `develop` tip is preserved at branch `archive/develop-snapshot-2026-05-30` (+ tag `develop-pre-reset-2026-05-30`). The unused candidate `baseline/main-equal-2026-05-30` can be deleted.
- `develop` is the staging source: pushing to `develop` auto-deploys the **backend** to `staging.reacti.io`. iOS staging builds are manual (`ios-testflight.yml`, `workflow_dispatch`).

---

## 3. CURRENT TASK (blocked) — finish the production deploy-key fix

**Why:** Production deploys over SSH from GitHub Actions, but the deploy key was being **rejected** by the server (confirmed via a read-only check — `Permission denied (publickey)`). Knocked out during a May backup-restore. Must be fixed before any production deploy.

**What's been done already:**
- Generated a fresh ed25519 deploy keypair.
- Loaded the new **private** key into the GitHub secret `DEPLOY_SSH_PRIVATE_KEY` (via `gh secret set`; private key never shown, already wiped).
- Created a **read-only** check workflow `.github/workflows/prod-deploy-check.yml` (on `develop`) that SSHes in and runs harmless commands only. Run it with:
  `gh workflow run prod-deploy-check.yml --ref develop` then check the run result.

**What's LEFT (the blocker):** install the matching **public** key on the production server's `root` authorized_keys. The long key kept breaking when pasted into the Hostinger browser terminal. Use the short-line method below.

**The new public key (safe to share):**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILwTsahsCbN6+y3V4GuUABqb9AV2rxYHOx7NxAeHv/ZE reacti-deploy
```
The base64 part alone (paste-safe, fits one line):
```
AAAAC3NzaC1lZDI1NTE5AAAAILwTsahsCbN6+y3V4GuUABqb9AV2rxYHOx7NxAeHv/ZE
```

**Install steps — Achia runs these in Hostinger → VPS → Browser Terminal (she is `root` on the prod VPS `72.61.202.136`). Run ONE LINE AT A TIME (short lines won't get mangled):**

1. `mkdir -p /root/.ssh && cd /root/.ssh`
2. `read -rp 'paste key: ' K`  → then paste the base64 line above, press Enter
3. `printf 'ssh-ed25519 %s reacti-deploy\n' "$K" >>authorized_keys`
4. `chmod 600 authorized_keys; tail -1 authorized_keys`

Step 4 should print exactly:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILwTsahsCbN6+y3V4GuUABqb9AV2rxYHOx7NxAeHv/ZE reacti-deploy
```
(If it's broken/partial, the paste mangled — redo. Do NOT `rm` authorized_keys; it may hold other keys. Always append.)

**Then the new Claude re-runs the check** (`gh workflow run prod-deploy-check.yml --ref develop`, wait, read the log). Green/`CONNECTED` = deploy path fixed. It also prints what version production is currently running.

> Note from the audit: production currently runs a `develop` commit `421502e` (from incident recovery 2026-05-23), NOT `main`. So "production" today ≠ `main` exactly.

---

## 4. The rest of the promotion plan (after Step 1 is green)

Make the real app match the verified `develop`. **Each production step is deliberate; pause for Achia.**

- **Step 2 — Promote `develop` → `main`.** Open a PR `develop → main` (squash/merge per the protect-main rules — needs the source-branch + code-owner checks). ⚠️ Heads-up: `main`'s backend CI is currently RED on a pre-existing Laravel security-advisory issue (see §6) — that may need handling for the promotion PR's required checks. This ships 167 commits forward, so review carefully.
- **Step 3 — Deploy backend to production.** Pushing to `main` triggers `backend-deploy.yml` (has a `production` Environment with Achia as required reviewer — she must approve). Deploys to `root@72.61.202.136:/home/reacti/htdocs/reacti.io/`, runs migrations, rebuilds caches. ⚠️ This changes the live API — confirm the live app stays healthy after (the patent/chat flow especially). Have a rollback plan (the archive + the previous deployed state).
- **Step 4 — iOS production release.** Build a **production** flavor release from `develop`/`main` (default identity `com.reacti.app`, NOT the staging flavor) and **submit to the App Store**. Needs Apple review (~1–3 days) before real users' app updates. There is no production iOS release pipeline yet — `ios-testflight.yml` is staging-only; a production equivalent must be built (or do it via Xcode/Transporter).
- **Step 5 — Confirm.** Once the App Store release is live and the backend is on `main`, production = the verified baseline = matches staging.

---

## 5. NEXT-LEVEL TASK — give staging its own push notifications

Staging currently sends **no** push notifications — on purpose, so it can't notify real production users (its Firebase credentials point at a non-existent "disabled" placeholder file `storage/app/private/STAGING-PUSH-DISABLED.json`; the error is caught/logged, not fatal). To make staging notify only the **Reacti Staging** app safely, set up a **separate staging Firebase project**:

1. Create a new Firebase project ("Reacti Staging"). *(Achia)*
2. Register iOS app `com.reacti.app.staging` → download its `GoogleService-Info.plist`. *(Achia)*
3. Upload the Apple **APNs auth key** (`.p8`, shared per Apple account) to that project's Cloud Messaging settings. *(Achia)*
4. Download a **service-account key** from the staging Firebase project. *(Achia → Claude places it on the staging server, sets staging `.env` `FIREBASE_CREDENTIALS`)*
5. Bake the staging `GoogleService-Info.plist` into the staging CI build (swap it in like `FlavorOverride`). *(Claude)*
6. Deploy + verify a message fires a push on Reacti Staging only. *(Both)*

---

## 6. Other open items

- **`develop` backend CI is RED (pre-existing, NOT our code):** the `PHP Tests` job runs `composer update`, which composer now **blocks** on a Laravel security advisory (`PKSA-mdq4-51ck-6kdq`) affecting `laravel/framework` 11.46–11.54. Live app/staging are UNAFFECTED (deploys use `composer install` with the lock). Fix = a deliberate Laravel security update (bump to a patched release) OR switch the CI step to `composer install` OR add `policy.advisories.ignore`. A focused dependency/security decision — not yet done.
- **Cleanup:** delete the obsolete `baseline/main-equal-2026-05-30` branch (keep `archive/develop-snapshot-2026-05-30` + its tag — that's the preserved history).

---

## 7. Key reference facts

- **Production server:** `root@72.61.202.136`, site dir `/home/reacti/htdocs/reacti.io/`, CloudPanel, site user `reacti`. Staging is the **same VPS**, user `reacti-staging`, dir `/home/reacti-staging/htdocs/staging.reacti.io/`. Achia uses the **Hostinger hPanel → VPS → Browser Terminal** (paste = right-click or Ctrl+Shift+V; long lines get mangled — keep commands short / one at a time).
- **GitHub:** repo `reacti25/reacti`. Default branch `develop`. `main` is protected (no direct push, PRs from `develop` only, code-owner review, required checks). `gh` CLI is authenticated as `reacti25`.
- **Prod deploy secrets:** `DEPLOY_SSH_HOST` (72.61.202.136), `DEPLOY_SSH_PORT` (22), `DEPLOY_SSH_USER` (root), `DEPLOY_SSH_PRIVATE_KEY` (just rotated). Staging: `STAGING_DEPLOY_SSH_*` + `STAGING_DEPLOY_TARGET_PATH`. iOS: `IOS_DIST_CERT_P12`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE`, `APPSTORE_CONNECT_KEY_ID/ISSUER_ID/API_PRIVATE_KEY`.
- **Key workflows:** `backend-deploy.yml` (prod, push to main + dispatch, production approval gate), `staging-deploy.yml` (push to develop + dispatch), `ios-testflight.yml` (staging iOS, dispatch, Flutter 3.41.x, build number `1000+run_number`), `prod-deploy-check.yml` (read-only prod SSH check).
- **Staging test accounts** (seeded by `backend/database/seeders/StagingTestAccountsSeeder.php`): `smoke-a@reacti.test`, `smoke-b@reacti.test` — friends, share "Smoke Test Group". Password is in Achia's offline file `reacti passwords\staging-test-accounts.txt` (NOT in repo).
- **TestFlight testers:** Achia = internal (auto-gets builds); her friend = internal now too. (External testers need each build released to them in App Store Connect.)
- **Patent flow (do NOT break):** silent front-camera recording when a recipient opens a sealed media message — `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` (`recordVideoSilently()` via `_buildBlurPlaceholder()` after `mark-viewed`). Any change to the blur/seal/record/mark-viewed/reaction-upload path needs a regression test.
- **Security habit:** never ask Achia to paste secrets/passwords into chat. Public keys are fine; private keys go via `gh secret set` from the workspace, never shown.

---

## 8. The single rule

No code reaches production until it's on staging, verified by tests + by Achia on her iPhone via TestFlight, AND (now) the production deploy path is confirmed working. We're at that last gate.
