# RESEARCH BRIEF — Viral "try-it" reaction demo (share via WhatsApp)

**Date:** 2026-07-01
**Author:** Achia (vision) + Claude (research plan + risk framing)
**Status:** Early research brief. **Highest uncertainty and highest legal risk of the
whole list.** Nothing gets built until the legal question in §3 is answered.
**Covers:** feature-list item **6** — instead of a plain invitation, let a Reacti user
send a *demo* (e.g. a Reacti video shared via WhatsApp) that a non-user can open and
have their reaction recorded, so they feel how Reacti works before installing.

---

## 1. The vision

Turn the invite into the product experience. A Reacti user shares a link (via WhatsApp,
etc.); a non-user taps it, watches the media, and — just like in Reacti — their
reaction is captured and can be sent back / shown to them, with a prompt to install the
app. A growth loop where the demo *is* the pitch.

## 2. Why this is the hard one

Everything else on the list is scoped or a config change. This one is a **new product
surface + a new legal exposure + platform constraints**, all at once:

- The whole point is recording a reaction — but the person being recorded is a
  **non-user who never accepted Reacti's terms.** That's the crux, and it dominates the
  design.
- It runs **outside the app** (a mobile web page opened from WhatsApp), so the app's
  existing (silent, in-app, consented) mechanism does not transfer.
- It rides on **WhatsApp and browser platforms** with their own rules and technical
  limits.

Treat this as: **legal feasibility → technical feasibility spike → growth design**, in
that order. Do not build the growth loop before the first two clear.

## 3. Legal — answer this FIRST (blocking)

The core question for counsel (same engagement as
`docs/LEGAL-BRIEF-consent-copy-2026-06-12.md` / DG1):

> Can we record a non-user's camera in a web demo, and under what consent UX, in our
> target markets (incl. EU/Israel)?

Sub-questions:

- Recording a person's face/reaction is sensitive processing. For a **non-user** with
  no prior relationship, you almost certainly need **explicit, in-page, pre-recording
  consent** — which **breaks the "silent, just like Reacti" premise.** That's likely
  unavoidable and actually fine (see §4 — the web can't do it silently anyway).
- **Minors:** shared links spread uncontrollably; a recipient could be a child. What
  age-gating / handling is required?
- **Data handling:** where is the recorded reaction stored, for how long, who sees it,
  and how does a non-user delete it? (GDPR data-subject rights apply even to non-users.)
- **Patent interaction:** the patent covers the *silent, in-app* flow. Does a
  *consented web* demo fall outside it, and does building it in any way weaken or
  complicate the patent claims? Flag explicitly to counsel.
- **WhatsApp/platform ToS:** does distributing this kind of link/recording experience
  via WhatsApp violate their terms?

**If counsel says explicit pre-recording consent is required (very likely), that's the
design** — reframe from "silently record like Reacti" to "an honest, playful *React to
this* web experience that shows a clear recording indicator." This is a better growth
artifact anyway (trust), and it's the only technically possible version (see §4).

## 4. Technical feasibility — a throwaway spike

Build a **disposable web prototype** (not in the app repo; a scratch project) to learn
the real constraints on a phone before committing:

- **Camera capture on mobile web:** `getUserMedia` + `MediaRecorder` to record the
  viewer's front camera while media plays; test specifically on **iOS Safari** (the
  strictest): permission prompt behaviour, whether recording works from a link opened
  **inside WhatsApp's in-app browser** (a known trouble spot — may need "open in
  Safari"), and `MediaRecorder` codec/output support on iOS.
- **Silent is impossible on web (good):** browsers *require* a visible permission prompt
  before camera access — you cannot record without the user seeing it. This resolves
  much of §3's tension: the web forces consent UX, so lean into it.
- **Autoplay with sound:** mobile browsers block autoplay-with-audio without a user
  gesture; the design must start playback on tap.
- **Media + upload:** how the shared media is hosted/served to the web page, and where
  the recorded reaction is uploaded (respect the reaction-media privacy rules in
  `PLAN-media-timing-and-speed` §Phase 4 — faces stay on the EU/consented path).
- **Deep-link handoff:** after the demo, deep-link/App-Store-link into Reacti, ideally
  carrying context (who invited them) via a deferred-deep-link tool
  (Branch/Adjust/Firebase Dynamic Links successor). Evaluate options.

Deliverable: a short **feasibility memo** — does iOS-Safari-from-WhatsApp actually
allow this, with what caveats, and is the experience good enough to ship?

## 5. Product / growth design

- Reframe as **"React to this"**: an explicit, fun, clearly-consented web reaction
  experience — visible camera indicator, a playful prompt, then "see your reaction" +
  "get Reacti to react with your friends."
- Study prior art: **BeReal**, **Locket**, **Sendit/NGL**-style web share loops — how
  they turned a share into installs, and their consent/permission UX.
- Decide the loop: what the inviter sends, what the invitee sees, what comes back to the
  inviter, and the install CTA. Instrument it (PostHog) as a funnel:
  link-open → camera-consent → reaction-recorded → install → signup.

## 6. Suggested phasing

1. **Legal go/no-go** (§3) — one question to existing counsel. Blocking.
2. **Technical spike** (§4) — throwaway web prototype, iOS-Safari-via-WhatsApp reality
   check. Cheap, do in parallel with legal.
3. **Growth design** (§5) — only if 1 and 2 are green.
4. **`PLAN-viral-demo-*.md`** — real build plan (new web surface + backend endpoints +
   deep-link handoff), Claude Code-ready, once 1–3 land.

## 7. Recommendation

This is the most exciting item and the most likely to be a growth unlock — but it's
**not a "learn and build" item.** Kick off the **legal question** and a **1–2 day
technical spike** in parallel; hold all product/build work until both return. Expect the
shippable version to be an **explicitly consented "React to this" web experience**, not
a silent clone of the in-app flow — and that's the right, defensible product.

## 8. Open questions for Achia

- Want me to draft the **counsel question** and the **spike scope** as concrete
  next artifacts?
- Is the web demo meant to send the reaction **back to the inviter** (needs the invitee
  to see/agree) or just **show the invitee their own** reaction as a hook?
- Appetite for a paid **deferred-deep-link** provider for attribution, or keep it simple
  (plain App Store link) for v1?

## 9. References

- `docs/LEGAL-BRIEF-consent-copy-2026-06-12.md`, `docs/PLAN-dg1-consent-flow-2026-06-12.md`
  — consent engagement + in-app model to stay consistent with.
- `docs/PLAN-media-timing-and-speed-2026-06-23.md` §Phase 4 — reaction-media privacy rules.
- `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` — the in-app
  reference mechanic (for parity of feel, not code reuse).
