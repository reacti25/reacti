# Needs Achia — parked decisions

Decisions and gates that need a non-engineering (product / legal / business)
call. Per the handoff, Claude Code does **not** block on these: it skips the one
gated item, records it here, and keeps working on everything else. Each entry
says what is needed, why, and what it blocks.

When you (Achia) decide one, tell Claude Code the answer (or edit the entry) and
the gated item is unblocked.

_Last updated: 2026-06-07._

---

## BLOCKER — production deploy path is down (operator + Hostinger)

- **Confirmed 2026-06-07** by the read-only `prod-deploy-check.yml` workflow:
  `ssh: connect to host ***: Connection timed out` (after a 15s connect timeout).
- **What it means:** the GitHub Actions runner cannot even open a TCP connection
  to the production server's SSH port — the connection times out *before* any
  login. So this is **not** an SSH key/password problem; it is a
  **network / firewall / server-availability** problem on the Hostinger side.
- **Likely causes:** prod server down or unreachable; SSH port closed/changed;
  or a Hostinger firewall blocking the deploy connection.
- **Needed (operator + Hostinger):** confirm the prod server is up, the SSH port
  is open, and the firewall allows the deploy connection; then re-run
  `prod-deploy-check.yml` until it is **green**.
- **Blocks:** every production backend deploy. `main` keeps accumulating verified
  changes that cannot reach real users until this is fixed. Staging is
  unaffected (it deploys to a different host and works).
- **Once green:** deploy the current `main` to prod as the first catch-up batch,
  run the post-deploy smoke tests, then promote in small frequent batches.

---

## Raise early (they gate the most)

### DG8 — original `composer.json` from the dev team
- **Needed:** the original `backend/composer.json` as shipped by the agency.
  Ours was reconstructed from `composer.lock`.
- **Why:** until it is trusted, CI must run `composer update` (resolves fresh
  versions) instead of `composer install` (the locked versions prod gets), so CI
  does not test exactly what deploys.
- **Blocks:** the `composer install` switch in Stage 0 / EP0. Everything else
  proceeds.

### DG1 — consent UX / disclosure for the silent recording
- **Needed:** product + legal decision on how the silent front-camera recording
  is disclosed/consented (one-time consent flow, visible indicator,
  privacy-policy linkage at the capture point).
- **Why:** covert face+voice capture with no consent UX is a GDPR /
  biometric-privacy liability and a likely App Store rejection. The patent
  feature itself stays; this is about disclosure.
- **Blocks:** the *consent* item in Stage 4d / EP4 only (a release blocker). The
  engineering hardening of the patent path does **not** wait on it.

---

## The rest (gate a single item each)

### DG2 — social login: wire it up or delete it
- Social login is entirely dead code (unrouted method, writes non-existent
  columns). Decide: implement correctly, or delete it.
- **Blocks:** one Stage 4c / EP3 item.

### DG3 — committed Firebase config
- `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`
  carry live Firebase keys and are committed. Decide: accept-as-public +
  document (Firebase client config ships in the binary anyway), or gitignore +
  provide `.example` templates + a FlutterFire-configure step. Either way,
  restrict the keys by app/bundle id in Google Cloud.
- **Blocks:** one Stage 4k / EP11 item.

### DG4 — light theme or dark-only
- The app has one hardcoded dark theme. Decide whether to support a light theme
  or commit to dark-only (drives how colour tokens are structured).
- **Blocks:** one Stage 4j / EP10 item.

### DG5 — language story
- Today: every string is hardcoded English, but the app sends
  `Accept-Language: pt` and runs errors through a no-op `.tr`. Decide: one
  hardcoded language (which?) or real localisation (`flutter_localizations` +
  ARB).
- **Blocks:** the Stage 4j / EP10 i18n item.

### DG6 — billing (Cashier)
- Cashier is pulled in (`Billable`, config, webhook CSRF exception) but billing
  is entirely unrouted — dead surface + extra dependency. Decide: finish billing
  or remove Cashier.
- **Blocks:** one Stage 4g / EP7 item.

### DG7 — v2 chat API is the keeper + client migration off v1
- Confirm the v2 chat API is the one to keep and plan the client migration off
  the duplicate v1 controller.
- **Blocks:** the Stage 4f route work and the Stage 4g v1 retirement.

---

## On hold (Achia's call, do not act unless she says so)

- **Roll `develop` back to the old version.** Floated, then put on hold. The
  handoff says treat `develop` as the working baseline and do **not** act on the
  rollback unless Achia explicitly re-confirms it.
