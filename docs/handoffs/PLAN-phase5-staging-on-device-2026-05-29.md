# Phase 5 — Staging on your iPhone (TestFlight) — Plan

**Date:** 2026-05-29
**Operator:** Achia (achia.rosin19@gmail.com)
**Purpose:** Get a *staging* build of Reacti onto Achia's iPhone so she can test
the `develop` version before it is promoted to `main` / production — without
affecting real users, and without losing the ability to talk to real users.
**Status:** Not started. Begins only with Achia's explicit go-ahead (per the plan
rule in CLAUDE.md).

> **Update (2026-05-30, after the loose-ends close-out):** The pre-work for this
> phase is mostly done. Staging is fully isolated (Firebase push disabled, S3 empty),
> and staging now has two real test accounts (`smoke-a@reacti.test` /
> `smoke-b@reacti.test`, friends, sharing a group — password in
> `reacti passwords\staging-test-accounts.txt`). The API contract-test wall is live.
> The only outstanding prerequisite is **re-installing the production deploy key**,
> and that gates the *production release* part of this phase — NOT the staging
> TestFlight build, which can proceed now. See Section 4.

---

## 0. The key idea (read this first)

Who an app can talk to is decided by **which server it points at**, not by where
the app was installed from.

- **staging.reacti.io** has its own separate, empty database. It is a sealed
  sandbox. An app pointed here **cannot reach real users** — by design.
- **reacti.io** (production) has the real users. An app pointed here talks to them.

You cannot be "on staging" and message real users in the *same* app. The solution
is to run **two apps on the phone at once.**

---

## 1. Recommended setup — two apps, side by side

| App on your phone | Built from | Points at | Who you reach | Comes from |
|---|---|---|---|---|
| **Reacti** (normal) | `main` | reacti.io (production) | Real users | App Store |
| **Reacti Staging** | `develop` | staging.reacti.io | Test accounts only | TestFlight |

- The **normal Reacti app stays exactly as it is.** You keep talking to real users
  there, like today. Nothing about your real account changes.
- **Reacti Staging** is a separate app with its own icon (we'll tint/label it so
  you never confuse the two). It installs *alongside* the normal app, so you never
  have to uninstall anything or switch back and forth.

This is why we give the staging app a **separate identity** (a distinct "bundle
id", e.g. `com.reacti.app.staging`): so both can live on the phone at the same time.

### Testing messaging inside the staging app

Real users aren't in the staging sandbox, so to test sending/receiving you talk to
a **second staging account**. ✅ **This is already set up:** staging has two seeded
test accounts — `smoke-a@reacti.test` and `smoke-b@reacti.test` — that are friends
and share a group (password in `reacti passwords\staging-test-accounts.txt`).

So to test the full flow (including the patent flow) you log into the staging app as
one account, and be the "other side" via a second device/simulator, or invite one
trusted tester to the staging TestFlight and have them use the second account.

---

## 2. The everyday flow once this is built

```
Push to develop ─► auto-builds "Reacti Staging" ─► lands in TestFlight on your phone (~15 min)
                                                    └─ you test the new changes safely

You approve ─► promote develop ➜ main ─► builds normal "Reacti" ─► App Store (real users)
```

So: try it on the staging app first, and only promote to production once you're happy.

---

## 3. What has to be built (Phase 5 work for Claude Code), in order

**A. App change — add a "staging" build flavor**
- Wire the API base URL to be set at build time (today it's hardcoded to production
  in `app/lib/networks/endpoints.dart` — the `BASE_URL` switch is commented out).
- Add a staging flavor: distinct bundle id (`com.reacti.app.staging`), app name
  "Reacti Staging", and a distinct icon, so it installs side-by-side.

**B. Apple one-time setup (you click, Claude Code guides each step)**
- Create an **App Store Connect API key** (for automated uploads).
- Register the staging **App ID** (`com.reacti.app.staging`).
- Create the iOS **distribution certificate**.
- Create **provisioning profiles** (staging + production).
- Create the **"Reacti Staging" app record** in App Store Connect + enable TestFlight.
- Add yourself (and any testers) as **TestFlight internal testers**.

**C. GitHub secrets** for the API key, certificate, and profiles.

**D. Workflow `ios-testflight.yml`** — on push to `develop`: build the staging
flavor (pointed at staging.reacti.io) on a GitHub macOS runner, upload to TestFlight.
*(You have no Mac — all iOS builds run on GitHub's Mac machines.)*

**E. (Later) Production release workflow** — on `main`: build the normal app
(pointed at production), upload to the App Store. Optionally a "release candidate"
TestFlight beta of the *production* app so you can do a final check against the real
backend with a few testers before all users get the update.

---

## 4. Must be green before Phase 5 starts (from the loose-ends pass)

1. **Verified production deploy path** — ⏳ STILL OPEN. The deploy SSH key needs
   re-installing on the server (~10 min, steps below). **Important:** this only gates
   the *production release* workflow (Section 3E) and the develop→main promotion. The
   **staging TestFlight build — the thing you actually want first — does NOT depend on
   it** and can be built now.
2. **Staging isolation gap closed** — ✅ DONE. Firebase push explicitly disabled, S3
   empty. Staging cannot leak into production.
3. **Staging seeded / test accounts created** — ✅ DONE. `smoke-a@reacti.test` and
   `smoke-b@reacti.test` exist, are friends, and share a group.

**Re-installing the production deploy key** (do before the production-release part):
1. PowerShell: `ssh-keygen -t ed25519 -f $HOME\.ssh\reacti_deploy_prod -C "github-actions-reacti-deploy" -N '""'`
2. Hostinger hPanel → VPS → SSH Keys → paste the contents of `reacti_deploy_prod.pub`.
3. Verify: `ssh -i $HOME\.ssh\reacti_deploy_prod root@72.61.202.136 whoami` → should print `root`.
4. Update the secret: `Get-Content $HOME\.ssh\reacti_deploy_prod -Raw | gh secret set DEPLOY_SSH_PRIVATE_KEY --repo reacti25/reacti`

---

## 5. Decisions to confirm

1. **Side-by-side staging app — ✅ DECIDED (2026-05-29).** Achia chose the
   side-by-side approach: a separate "Reacti Staging" app with its own icon, living
   alongside the normal Reacti app. Build accordingly (distinct bundle id, name, icon).
2. **Who tests messaging with you** — a second account on a spare device, or invite
   one trusted tester.
3. **Auto-upload to TestFlight on every `develop` push**, or only on demand.
4. **(Later) Production release-candidate beta** — do we also TestFlight the
   production app before full App Store release? (Recommended eventually; this is the
   final real-world check against the real backend before all users update.)

---

## 6. Rough effort

1–3 working sessions. Most of it is one-time Apple account setup (you clicking
through Apple's site with step-by-step guidance) plus one new build workflow. After
that it's automatic: push to `develop`, the staging app updates on your phone.

---
