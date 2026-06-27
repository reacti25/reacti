# Plan — DG1 silent-recording consent flow (2026-06-12)

**Author:** Cowork (operator session) · **Executor:** Claude Code · **Owner/approver:** Achia
**Status:** the **release-gating** feature. The first new-app App Store release is
held until this is in and green on staging (Achia's lawyer's requirement).

## Why this exists

Reacti's patented feature silently records the recipient's front camera when they
open a media message. Shipping that to the App Store requires the user to have
**consented** first. DG1 (Achia's call, 2026-06-08) is to **build a consent +
disclosure flow** that keeps the patented feature for users who accept.

> ⚖️ **Legal wording is NOT engineering's to write.** Claude Code builds the
> *mechanism* with clearly-marked **placeholder** copy (`[[CONSENT_COPY_PENDING_LAWYER]]`).
> The real consent/disclosure text comes from Achia's lawyer and is a **gate
> before release** — do not ship with placeholder copy.

## The behaviour to build (Achia's spec, 2026-06-08)

1. **Consent shown once at registration.** During sign-up (after OTP verify), the
   user sees the disclosure + consent for silent reaction-recording.
2. **Decline or later revoke OS camera permission → cannot use the reaction
   feature** (private *or* group). The patented capture simply does not run for
   them.
3. **Capture-point fallback.** If a user without consent/permission taps to open
   new blurred media, a **pop-up** explains they must consent, and offers to
   **grant consent + camera permission inline**, or **cancel** (and not view it).
4. **Keep the patented feature for those who accept** — consented users get the
   exact silent-record → reaction loop as today.

## Current code anchors (verified)

- **Capture point:** `app/lib/features/chat/presentation/widget/receiver_message_widget.dart`
  — `_buildBlurPlaceholder()` calls `mark-viewed` then, on success,
  `recordVideoSilently()` (→ `reactionRecorder.record()`). It already handles
  permission-denied by no-op'ing silently — that path becomes the pop-up.
- **Registration:** `app/lib/features/auth/presentation/signup/signup_screen.dart`
  and `.../signup_verify_otp/signup_verify_otp_screen.dart`,
  `app/lib/helpers/register_provider.dart`.
- **Permissions:** `permission_handler: ^12.0.1`, `app/lib/helpers/permission_helper.dart`,
  and the `app/lib/features/permission/` screens — reuse these; don't add a new
  permission lib.
- **Consent storage:** none yet. Constants live in
  `app/lib/constants/app_constants.dart` (`kKey…` GetStorage keys).

## Guardrails (load-bearing — read `clean-code-standards` SKILL.md Part 2)

- **This is the patent path.** Per the North-Star rule, any change to the
  blur/unblur transition, the recording trigger, `mark-viewed`, or the reaction
  upload **must** ship with an end-to-end regression test exercising the full
  loop. The existing patent-flow harness (InboxScreen + GroupInboxScreen) must
  stay green and be extended for the consented / not-consented branches.
- **Consent must be obtained BEFORE any silent capture.** The gate sits in front
  of `mark-viewed` + `recordVideoSilently()` — never record first and ask later.
- Small PRs off `develop`; keep **"Analyze & Test"** green; DartDoc; match GetX /
  `rx_*` / `get_it` patterns; `StatefulWidget` config fields `final`.
- Placeholder legal copy only; real wording is a release gate.
- Don't promote to `main`, touch the App Store, or deploy.

---

## 🔒 DECISION (Achia + lawyer) — where is consent recorded?

This shapes scope. Pick before C1:

- **Option 1 — server-recorded (recommended for legal defensibility).** Store a
  timestamped consent on the user (e.g. `recording_consent_at`) via a small
  **additive** endpoint. Survives reinstall / new device; auditable proof of
  consent. Backend change is additive (new column + endpoint) so it does **not**
  change existing response shapes — safe to deploy ahead of the app and no risk
  to the OLD live app. App-only mirror in GetStorage for fast local checks.
- **Option 2 — local-only (simpler, app-only).** Store consent in GetStorage
  only. No backend work, but consent is lost on reinstall and there's no
  server-side audit trail — weaker if consent is ever challenged.

**Default if unspecified:** Option 1. Confirm with the lawyer (it's their
defensibility need).

---

## Phase 1 — App-side consent mechanism

### F1 — Consent state + storage
**Branch:** `feat/dg1-consent-state`
- Add a consent key (`kKeyRecordingConsent` + timestamp) in `app_constants.dart`
  and a small `ConsentService` (get_it singleton) exposing
  `hasConsented`, `grantConsent()`, `revokeConsent()`.
- If Option 1: wire `grantConsent()` to the additive backend endpoint (F5) and
  mirror locally; treat the server value as source of truth on login.
- Unit tests for the service (granted / not-granted / revoke).

### F2 — One-time consent at registration
**Branch:** `feat/dg1-consent-registration`
- After successful OTP verification (`signup_verify_otp_screen.dart`), present the
  disclosure + consent screen using placeholder copy
  `[[CONSENT_COPY_PENDING_LAWYER]]`. Accept → `grantConsent()`; decline →
  proceed without consent (reaction feature stays off).
- Widget tests: accept path sets consent; decline path leaves it unset.

### F3 — Capture-point consent + permission gate (the patent path) ⚠️
**Branch:** `feat/dg1-capture-gate`
- In `receiver_message_widget.dart` `_buildBlurPlaceholder()`, **before** calling
  `mark-viewed` / `recordVideoSilently()`, check `hasConsented` **and** OS camera
  permission (via `permission_helper.dart`).
  - Both present → existing silent-record → reaction loop, unchanged.
  - Missing either → show the **consent/permission pop-up**: explain, offer
    **grant consent + permission inline** (then proceed to view + record) or
    **cancel** (media stays blurred/unviewed; nothing recorded, no `mark-viewed`).
- **Regression tests (required):** extend the patent-flow harness so that
  (a) consented + permitted → full loop fires exactly as today (mark-viewed →
  record → reaction upload → unblur), and (b) not-consented → pop-up shown, **no**
  mark-viewed, **no** record, **no** reaction. Run the full chat-presentation
  suite; it must stay green.

### F4 — Enforce "no consent/permission → no reaction feature"
**Branch:** `feat/dg1-enforce-gate`
- Ensure both private and group capture paths honour the gate (same widget, but
  verify both screens). On OS-permission revoke, `hasConsented` alone is not
  enough — the live permission check in F3 covers it; add a test simulating
  revoked permission → pop-up, no capture.

### F5 — (Option 1 only) Backend consent record
**Branch:** `feat/dg1-consent-endpoint` (backend)
- Additive: migration adding `recording_consent_at` (nullable timestamp) to
  `users`; a `POST` endpoint to set it (auth'd), returning the standard envelope;
  include it in the user payload read on login. **Do not** change any existing
  response shape. Feature + Contract tests; update the relevant `Contract` test
  for the user payload's new (additive) field.
- Because it's additive, it is safe to deploy ahead of the app and harmless to the
  OLD live app.

---

## Testing summary

- Unit: `ConsentService`.
- Widget: registration accept/decline; capture-point pop-up shown when
  ungated; inline grant proceeds.
- **Patent-flow regression (non-negotiable):** consented loop unchanged;
  not-consented blocks capture entirely. Full harness green on every PR.
- Backend (Option 1): Feature + Contract tests for the additive endpoint/field.
- `cd app && flutter test && flutter analyze` green; `php artisan test` green if
  F5 is in scope. Required checks **"PHP Tests"** + **"Analyze & Test"** green.

## Staging validation (on-device, Reacti Staging TestFlight)

After merge to `develop`, build a fresh staging TestFlight (`ios-testflight.yml`)
and verify with `smoke-a` / `smoke-b`:

1. Register a fresh account → consent disclosure appears once; accept.
2. Consented user opens received blurred media → silent-record → reaction →
   unblur loop still works (the patented feature, intact).
3. Second account declines consent (or revoke camera permission in iOS Settings)
   → opening blurred media shows the pop-up; cancel → media stays blurred, nothing
   recorded; inline-grant → proceeds.
4. Confirm parity in a **group** chat.
5. Placeholder copy is visibly placeholder (so no one mistakes it for final).

## Release impact — this unblocks the first release

Once this is **in and green on staging** (and the lawyer's real copy is dropped
in), it clears the DG1 gate. The first App Store release is then assembled from
`main`:

- **Content:** consent flow + the composer fix + the verified security batch
  (Phases A/B). Leave unfinished work (testing-plan Phase C, B1/B3) on `develop`,
  unpromoted — so the release is insulated from it.
- **App-first:** Achia drives the App Store submission; **then** the operator
  deploys the backend (Option 1's additive endpoint can be deployed first since
  it's backwards-compatible). The operator must first restore a working prod
  deploy path (the Hostinger rate-block / deploy-key issue).
- ⚖️ **Final legal copy in place** is a hard pre-submission gate.

## Definition of done

- Consent shown once at registration; decline/revoke → reaction feature off.
- Capture-point pop-up offers inline grant or cancel; consented loop unchanged.
- Patent-flow regression proves: consented = full loop; not-consented = no
  capture at all.
- Placeholder copy clearly marked; lawyer's wording tracked as the release gate.
- Green on required checks; verified on the Reacti Staging TestFlight build.
- `NEEDS-ACHIA.md` DG1 marked implemented (pending final copy); `PROGRESS.md`
  updated.

---

## Kickoff prompt for Claude Code

```text
Read .claude/skills/clean-code-standards/SKILL.md (especially Part 2, the
North-Star patent-path rule) and docs/PLAN-dg1-consent-flow-2026-06-12.md.
Build the DG1 silent-recording consent flow — the release-gating feature.

This touches the LOAD-BEARING patent path. Consent MUST be obtained before any
silent capture: the gate sits in front of mark-viewed + recordVideoSilently() in
receiver_message_widget.dart's _buildBlurPlaceholder(). Every PR that touches the
blur/record/mark-viewed/reaction path ships with the full patent-flow regression
harness green, extended for consented (full loop unchanged) vs not-consented (no
mark-viewed, no record, no reaction).

Use placeholder legal copy [[CONSENT_COPY_PENDING_LAWYER]] everywhere user-facing
— do NOT invent consent wording; the lawyer supplies it and it's a release gate.

First, confirm the storage decision with Achia (server-recorded [recommended,
additive backend endpoint + recording_consent_at column] vs local-only GetStorage).
Default to server-recorded. Then build in small PRs off develop:
  F1 ConsentService + storage, F2 one-time consent after OTP verify, F3 capture-
  point consent+permission gate with the pop-up (reuse permission_helper.dart),
  F4 enforce no-consent/permission -> no reaction in private AND group, and
  (if server-recorded) F5 the additive backend endpoint with Feature+Contract
  tests (no existing response shape changes).

Guardrails: small PRs off develop, keep "PHP Tests" + "Analyze & Test" green,
DartDoc, match GetX/rx_*/get_it patterns, StatefulWidget config fields final.
Don't promote to main, touch the App Store, or deploy. When green on develop,
tell Achia it needs a fresh Reacti Staging TestFlight build for the on-device
checklist (register+consent, consented loop intact, decline/revoke -> pop-up +
no capture, group parity). This feature, once verified AND with the lawyer's real
copy dropped in, unblocks the first App Store release (consent + composer fix +
verified security; app-first). Keep testing-plan Phase C held unless told
otherwise.
```
