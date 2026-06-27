# Resolved decision gates — for Claude Code

Achia made these calls (via the operator session) on **2026-06-08**. They
resolve the gates parked in `NEEDS-ACHIA.md`. Claude Code: implement these,
and fold the resolutions into `NEEDS-ACHIA.md` (mark each DG resolved).

---

## Resolved

- **DG6 — Billing → REMOVE.** No monetization planned. Remove the Cashier/Stripe
  surface (`Billable` on `User`, `config/cashier.php`, the `stripe-webhook` CSRF
  exception, the dependency). *(Unblocks the 4g/EP7 Cashier item.)*

- **DG5 — Language → MULTIPLE (real localization).** Add `flutter_localizations`
  + ARB infrastructure and route UI strings through it; fix the
  `Accept-Language` mismatch (app sends `pt` while strings are English).
  **Scope now:** build the i18n framework + an English baseline. The actual
  additional languages will be specified by Achia later — don't hardcode a
  second language yet. *(Unblocks the 4j/EP10 i18n item.)*

- **DG9 — Account deletion → HARD-DELETE (permanent).** Keep current behaviour
  (GDPR right-to-erasure). Do **not** add `SoftDeletes`. Clean up the
  schema/model mismatch by removing the unused `deleted_at` column and the
  `whereNull('deleted_at')` filters. *(Resolves the EP5 SoftDeletes item.)*

- **DG1 — Silent-recording consent → BUILD a consent + disclosure flow.** Add a
  one-time consent screen + a privacy disclosure at the capture point
  (`receiver_message_widget.dart` blur-placeholder path), keeping the patented
  feature. **Build the mechanism now; final legal wording will be reviewed by a
  lawyer (Achia).** This flow is a **release blocker for the silent-recording
  feature** → it must be in the next App Store release. *(Unblocks the 4d/EP4
  consent item.)*

- **DG7 — v2 chat is the KEEPER.** Do the 4f/EP6 API work on v2. **DO NOT retire
  the v1 chat controller yet** — the live App Store app may still use it; v1
  retirement waits until the new app is live and adopted (same app/backend
  coupling that caused the prod incident). *(Unblocks 4f route work; the 4g v1
  retirement stays deferred.)*

- **DG2 — Social login → DELETE** the dead social-login code (unrouted method +
  non-existent column writes). *(Unblocks the 4c/EP3 item.)*

- **DG3 — Committed Firebase config → ACCEPT + DOCUMENT.** Leave the config
  committed (client config ships in the binary anyway); document it. **Achia
  will restrict the Firebase API keys by app/bundle id in Google Cloud** — that
  part is hers, not Claude Code's. *(Unblocks the 4k/EP11 item.)*

- **DG4 — Theme → DARK-ONLY for now.** Structure colour tokens for a single dark
  theme; defer light-mode support. *(Resolves the 4j/EP10 theme item.)*

## Still pending (not Claude Code's to resolve)

- **DG8 — original `composer.json`:** Achia will request it from the original
  dev/agency. Until it arrives, CI stays on `composer update`. No action for
  Claude Code yet.

---

## Release implication

Because DG1's consent flow is a release blocker for the recording feature, the
**next App Store release batch = security (4a/4b) + correctness (4c) + the
consent flow (4d) + patent hardening**. Hold the `🚀 RELEASE MILESTONE` signal
until the consent flow is in and green on staging, so the app you ship is
App-Store-safe. (Operator + Achia drive the actual release — app first, then
backend.)
