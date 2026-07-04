# BRIEF — Recording consent at signup (fold into terms?)

**Date:** 2026-07-01
**Author:** Achia (idea) + Claude (findings + legal-decision framing)
**Status:** Legal-strategy decision brief. **Needs counsel's opinion, not just code.**
**Covers:** the consent half of feature-list item **5** — "when someone signs up they
have to approve the terms anyway, so make recording consent one of them (fold it into
the sign-up consent)."

---

## 1. The idea, and why it's not a pure build task

Achia's proposal: since signup already requires accepting Terms & Conditions, roll the
**silent-reaction-recording consent** into that same acceptance, so there's one tick
instead of a separate step. Simpler UX, fewer taps.

This is reasonable UX instinct, **but it's a legal-strategy call, not a coding one** —
and it may directly conflict with the already-approved consent design. Get it wrong and
the risk isn't a bug; it's an invalid consent for the app's most sensitive, patent-
defining feature (recording someone's face).

---

## 2. What already exists (and why it matters)

- **Signup already has a Terms & Conditions checkbox:**
  `app/lib/features/auth/presentation/signup/signup_screen.dart` (≈L174–436) — signup
  is blocked until `isAccept` is true; links to
  `app/lib/features/terms/presentation/terms_screen.dart`.
- **A full, approved plan already governs recording consent:**
  `docs/PLAN-dg1-consent-flow-2026-06-12.md`. It deliberately makes recording consent a
  **separate, explicit, post-OTP step** — not part of the general T&C — with its own
  copy (`[[CONSENT_COPY_PENDING_LAWYER]]`), a capture-point gate in
  `receiver_message_widget.dart`, and a stored `kKeyRecordingConsent` flag. There's a
  companion legal brief: `docs/LEGAL-BRIEF-consent-copy-2026-06-12.md`.
- So Achia's idea **diverges from DG1**, which intentionally *separated* recording
  consent. The question is whether to keep DG1's separation or merge per Achia's idea.

**This brief must not be implemented independently of DG1.** Whatever is decided updates
DG1; it doesn't run around it.

---

## 3. The legal argument (why DG1 separated it — the case for keeping separate)

Bundling consent for silent face-recording into a generic "I accept the Terms" checkbox
tends to produce **weaker, more challengeable consent**:

- Consent for sensitive processing (recording a person's face/reaction) is generally
  expected to be **specific, informed, unbundled, and freely given** (GDPR-style
  standards; some jurisdictions treat facial recordings especially strictly).
- A single checkbox mixing "I accept the Terms" with "I consent to being recorded"
  risks being deemed **not specific** and **not freely given** (you can't use the app
  without accepting the Terms, so the recording consent isn't really a free choice).
- DG1 also handles the **recipient** side (the person being recorded when they open
  media) and permission-revocation — a signup checkbox can't cover a recipient who
  isn't the account holder in that moment. DG1's **capture-point gate** exists for
  exactly this.

That's likely *why* DG1 put recording consent as its own explicit step. So the default
recommendation is **keep it separate** unless counsel says bundling is fine in your
target markets.

---

## 4. The case for Achia's idea (present it fairly)

- Fewer steps = higher signup completion; every extra screen costs conversions.
- If counsel confirms that, for Reacti's markets and framing, a clearly-worded,
  prominently-surfaced recording consent *within* the signup acceptance meets the
  "specific and informed" bar, then merging is a legitimate simplification.
- A middle path exists (see §5) that keeps one screen but two distinct, separately-
  recorded acknowledgements — potentially the best of both.

---

## 5. Options to put to counsel

1. **Keep DG1 as-is** — separate post-OTP recording-consent step. Safest; already
   designed.
2. **Merge fully** — one checkbox covers Terms + recording consent. Simplest UX,
   **highest legal risk**; only if counsel explicitly blesses it.
3. **One screen, two ticks (recommended middle path)** — at signup, show the Terms
   acceptance *and* a distinct, separately-ticked, plainly-worded recording-consent
   line ("I understand and agree that when I open a photo/video, my reaction is
   recorded and sent back"), each stored independently (`isAccept` +
   `kKeyRecordingConsent`). Keeps it to one screen while preserving specific, unbundled
   consent — and still keep DG1's **capture-point gate** for the recipient case.

---

## 6. Process (what actually unblocks this)

1. **Ask counsel** (the same lawyer producing DG1's `[[CONSENT_COPY_PENDING_LAWYER]]`):
   can recording consent be collected at signup — merged (Option 2) or one-screen-two-
   ticks (Option 3) — for Reacti's markets, and what wording is required? This is one
   question added to the consent-copy engagement already in flight.
2. Based on the answer, **update `PLAN-dg1-consent-flow`** (don't create a competing
   flow). If Option 3, DG1's F2 ("one-time consent after OTP") moves to signup; F3/F4
   (capture-point gate) stay.
3. Then it becomes a normal client build under DG1's plan.

---

## 7. Recommendation

Pursue **Option 3 (one screen, two ticks)** as the proposal to counsel — it satisfies
Achia's "don't make it a separate step" goal while preserving specific, unbundled
consent and keeping DG1's recipient-side gate. **Do not ship any variant without
counsel's written sign-off**, given this is the patent-defining, face-recording
feature.

---

## 8. Key files / references

- `app/lib/features/auth/presentation/signup/signup_screen.dart` — existing T&C checkbox.
- `app/lib/features/terms/presentation/terms_screen.dart` — terms content.
- `app/lib/features/auth/presentation/signup_verify_otp/...` — where DG1 puts consent today.
- `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` — capture-point
  gate location (patent flow — behaviour must not break).
- `docs/PLAN-dg1-consent-flow-2026-06-12.md` — the governing plan (update this).
- `docs/LEGAL-BRIEF-consent-copy-2026-06-12.md` — counsel engagement (add the question here).
