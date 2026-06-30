# Runbook — v1.2.0 release: production analytics live (2026-06-17)

**Goal:** turn on **production analytics** (real-user numbers + the meaningful
"Usage Data" opt-out), and ship everything banked on `develop` (ponytail cleanups +
the #12 reset de-dup) to the App Store. **Version: 1.2.0.**

**Explicitly NOT in this release:**
- **DG1 consent flow** — stays parked on `feature/dg1-consent` (needs lawyer copy).
- **Mailtrap** — staging-only. **Production keeps its own real mail server** and
  sends real reset/verification emails to users, exactly as it does now.

**What ships:** the current `develop` (rebuilt app + Phase A/B security + composer
fix + is_viewed fix + ponytail cleanups + #12), built **with prod analytics keys**
so analytics goes live. Consent is already off `develop`, so nothing to lift this
time.

---

## Phase A — Enable prod analytics (prep; no production impact yet)

**Achia — governance (free, ~10 min, do anytime before the release):**
- **PostHog** → Settings → accept/download the **DPA**; confirm **EU** region; set
  **data retention** (90 days is fine).
- **Sentry** → Settings → Legal/Compliance → accept the **DPA**; confirm **EU**.
- (Can wait) add a line to your privacy policy that the app uses privacy-friendly
  analytics with an opt-out — not lawyer work, just disclosure.

**Claude Code — wiring (prep; staging stays unaffected):**
- Generate a **distinct prod salt** `ANALYTICS_HASH_SALT_PROD` → GitHub secret
  (so prod ids aren't linkable to staging ids). **Reuse** the existing
  `POSTHOG_KEY` + `SENTRY_DSN_*` secrets — it's one PostHog project + shared Sentry
  projects, separated by the `analytics_env` tag.
- Wire **`ios-release.yml`** to build the app with `ANALYTICS_ENV=production` + the
  prod keys/salt via `--dart-define`, so the v1.2.0 app sends app-side events
  tagged `production`.
- Wire **`backend-deploy.yml`** to sync the prod analytics env vars
  (`ANALYTICS_ENV=production`, `POSTHOG_KEY`, `POSTHOG_HOST`, the prod salt,
  `SENTRY_LARAVEL_DSN`, sample rates) into the prod server `.env` — mirroring the
  staging-deploy pattern, behind the existing `production` approval gate.
- Confirm: prod tags `analytics_env=production`; staging untouched; default-off if
  keys ever absent; no API-shape change (Backwards-Compat stays green).

**Dashboards (not a release blocker):** clone the 5 staging dashboards to a
`production`-filtered set — either Claude Code with a temporary write key, or Achia
duplicates them in the PostHog UI and switches the filter to `analytics_env=production`.
Best done once prod data is flowing.

---

## Phase B — The production release (app-first)

Follow **`docs/RUNBOOK-first-production-release-2026-06-12.md`** — same process as
v1.1.0 — with these specifics:

1. **Version bump:** `app/pubspec.yaml` → `1.2.0+12` → PR to `develop`.
2. **Pre-flight gates (all green before touching prod):**
   - `develop` is the candidate (consent already off it — nothing to lift).
   - All required checks green incl. **Backwards Compatibility**.
   - `prod-deploy-check.yml` green (deploy path healthy — run once, no loops).
   - **Fresh VPS snapshot** taken right before the deploy (single slot — don't
     overwrite a rollback point you still want).
3. **Promote** `develop → main` (Achia approves + merges; the develop-only-to-main
   rule passes).
4. **Order — backend-first with the old-app canary** (backwards-compat is proven):
   operator deploys the backend (with the prod analytics env) → **immediately verify
   the OLD live app still works** → only then release the new app. Roll back the
   snapshot if the canary breaks.
5. **App:** tag `v1.2.0` on `main` → `ios-release.yml` builds **with prod analytics
   keys** → App Store Connect → Achia submits → **phased release**.

---

## Phase C — Post-release verification (on prod)

- **Analytics live:** your **production** dashboard shows events tagged
  `analytics_env=production` from real users (app_open, message_sent, the
  overlap metric, message_persisted, api_request).
- **One identity:** app + backend share one **salted** id (the new prod salt).
- **Opt-out is now real:** toggle **Usage Data off** in the live app → your events
  stop; back on → they resume.
- **Forgot-password in prod:** run forgot-password in the **live** app → the real
  reset email arrives in **your real inbox** (not Mailtrap) → code works → reset
  succeeds. (Confirms #12 + the live mail.)
- **Patent flow + general sanity** on the live app.

---

## Guardrails (unchanged)

- App-first; backend-first-with-canary for the deploy; snapshot rollback ready;
  don't hammer prod SSH (Hostinger rate-block); both branch-protection systems agree.
- Mailtrap stays staging-only; prod mail untouched.
- Consent flow NOT shipped (parked).
- Prod analytics is privacy-first: no PII/content/location, pseudonymous (prod
  salt), opt-out honored app + backend, EU region.

---

## Kickoff for Claude Code (Phase A wiring — prep only)

```
Read docs/RUNBOOK-v1.2.0-analytics-live-2026-06-17.md. Do Phase A wiring only —
prep, no production impact, staging untouched:
- Generate ANALYTICS_HASH_SALT_PROD (distinct prod salt) → GitHub secret. Reuse the
  existing POSTHOG_KEY + SENTRY_DSN_* secrets (one PostHog project + shared Sentry
  projects, separated by analytics_env).
- Wire ios-release.yml to build with ANALYTICS_ENV=production + prod keys/salt via
  --dart-define (app-side events tagged production).
- Wire backend-deploy.yml to env-sync the prod analytics vars into the prod .env
  behind the existing production approval gate (mirror staging-deploy).
- Confirm no API-shape change (Backwards-Compat green), staging unaffected,
  default-off preserved. Report what you changed + exactly what Achia must do
  (DPAs/retention) before the release. Do NOT promote to main, deploy, tag, or
  touch the App Store — pause after the wiring for Achia.
```
