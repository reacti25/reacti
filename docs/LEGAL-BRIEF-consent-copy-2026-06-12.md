# Reacti — brief for legal review: silent reaction-recording consent & disclosure

**Prepared for:** Achia's lawyer · **Date:** 2026-06-12
**Ask:** draft the user-facing **disclosure + consent wording** for a camera
feature, and confirm our consent mechanism is sufficient. This brief describes
exactly what the feature does and where consent is requested so the wording fits
the product. Nothing ships until your wording replaces our placeholder.

> Bracketed `[[…]]` items are facts for Achia to confirm/fill before sending.

## What the feature does (plain facts)

- Reacti is an iOS messaging app (App Store). Its core, patented feature: when a
  recipient **opens a media message** (photo/video) sent to them, the app
  **automatically and silently records a short video from their front camera** at
  the moment they view it — capturing their reaction — and sends that recording
  back to the original sender as a "reaction" message.
- At the moment of capture the recording is **silent** — `[[confirm: is there any
  on-screen indicator/preview shown to the person being recorded at capture time?
  state the exact current behaviour]]`.
- The reaction video is uploaded to Reacti's server and delivered to the sender.
  `[[confirm: retention period; who can access it; whether the sender can
  save/forward it]]`.

## Where & how we capture consent (the mechanism already built)

1. **One-time at registration.** Right after sign-up, a dedicated screen presents
   the disclosure and asks the user to agree **before** they can use the reaction
   feature. Agree → consent recorded; decline → the recording feature is disabled
   for them.
2. **Capture-point fallback.** If a user who hasn't consented (or who has revoked
   iOS camera permission) taps to open new media, a pop-up explains they must
   consent + grant camera permission to view it, and offers to do so **inline** or
   **cancel** (and not view it).
3. **Consent is stored server-side with a timestamp** (auditable). Revoking the
   iOS camera permission also disables the feature. Consent is obtained **before**
   any recording occurs.

## What we need from you

- **A.** Disclosure + consent wording for the **registration screen**.
- **B.** Wording for the **capture-point pop-up**.
- **C.** The short iOS **camera-permission string** (`NSCameraUsageDescription`)
  the operating system shows at the permission prompt.
- **D.** Confirmation that one-time, server-recorded consent + the mechanism above
  is **sufficient**, or what to change.

## Questions so the wording is correct

- **Jurisdictions / users:** where are our users located? `[[Achia to provide]]`.
  Any two-party/all-party recording-consent laws, GDPR (EU), biometric statutes
  (e.g. US BIPA), or local rules that apply?
- Must the copy explicitly state: **what** is recorded (front-camera video),
  **when** (on opening media), that it is **sent to the sender**, **where/how long**
  it's stored, **how to withdraw** consent, and **who can access** it?
- Does our **privacy policy / terms** need updating to match? (The app has privacy
  and terms screens we can revise.)
- Any **Apple App Store review** considerations for silent front-camera capture
  you want reflected in the wording?
- **Minors:** does Reacti permit under-18 users? `[[confirm]]` If so, is different
  handling or parental consent required?
- Is **withdrawal/erasure** wording needed (right to delete past reactions)?

## How your wording plugs in

Today every user-facing consent string in the app is the placeholder marker
`[[CONSENT_COPY_PENDING_LAWYER]]` (in `app/lib/features/consent/consent_copy.dart`).
When you provide A–C, we drop your exact wording in (a small, isolated change),
re-verify on a test build, and it ships in the next App Store release. **The app
is blocked from release while the placeholder is present**, so your wording is the
gate.
