# PLAN — Wireframe "8 Beta Deliveries" (2026-07-21)

_Source: `docs/✓ App wireframes design.pdf` ("Reacti — Beta Delivery Mockups",
8 planned deliveries). This doc sorts every delivery into **HAVE / GAP / NEW**,
maps it to work already shipped or planned so nothing gets rebuilt, and proposes a
build sequence. **Planning only — nothing here is approved to build yet.** Achia and
Claude will trim this down before any branch is cut._

Status verified against the docs read on 2026-07-21: `FEEDBACK-triage-2026-07-14.md`,
`PLAN-quick-wins-tester-feedback-2026-07-14.md`, `PLAN-ux-fixes-2026-06-28.md`,
`PLAN-theme-and-media-picker-2026-07-01.md`, `PLAN-whatsapp-media-2026-07-16.md`,
`RESEARCH-BRIEF-onboarding-and-first-use-2026-07-01.md`,
`RESEARCH-BRIEF-viral-reaction-demo-2026-07-01.md`, and project memory. Prod at time
of writing = 1.3.1+ (App Store), active line 1.3.2 on `develop`.

## Legend

- **HAVE** — already shipped to prod or merged/queued on `develop`. Verify on device; do not rebuild.
- **GAP** — most of it exists; one concrete piece is missing. Small build.
- **NEW** — genuinely not built. Sized S / M / L.
- **DECISION** — needs a product/legal/nav call from Achia before it can be built.

---

## Headline

Roughly half of the wireframe is **already done or on `develop`**. The real new
surface area is four things: the **demo Reacti (#2)**, the **personal invite (#5)**,
the **group react-to-unlock (#6)**, and the **chat-list preview labels (#3d)**. The
rest is polish, reuse, or a decision. This plan is therefore mostly "finish the gaps
and decide the big three," not a from-scratch build.

---

## Delivery 1 — Onboarding screens (3 swipes, then try it immediately)

**Wireframe:** "Send the moment" → "Catch the real reaction" → "No retakes. Just real.",
then let the user try it immediately.

- **HAVE** — a 3-slide pre-signup carousel exists
  (`app/lib/features/onboard/presentation/on_board_screen.dart`, `PageView` +
  `smooth_page_indicator`, Skip + Next/Get Started). First-run routing in
  `app/lib/loading.dart` via `kKeyIsFirstTime`. Slides today: "Share Authentic
  Moments" / "Your Privacy Matters" / "Reaction to View".
- **HAVE (queued)** — "return to intro from login" is specced as QW3 in
  `PLAN-quick-wins-tester-feedback-2026-07-14.md` (add a "How Reacti works" link on
  the login screen that re-opens the carousel).
- **GAP** — the wireframe copy is sharper than the live slides. A **copy + visual
  refresh** of the 3 slides to match the wireframe (lead with the reaction hook) is a
  small, self-contained change.
- **NEW** — the "then let the user **try it immediately**" half of this delivery **is
  Delivery 2** (the demo). Onboarding isn't "done" until #2 exists.
- **Also relevant** — `RESEARCH-BRIEF-onboarding-and-first-use-2026-07-01.md` argues
  the highest-leverage missing surface is an **in-app first-message coach-mark**, not
  the carousel. Keep that brief's north-star activation metric in view; don't polish
  the carousel in isolation.

**Verdict:** carousel HAVE; copy refresh = GAP (S); "try it now" = Delivery 2.

---

## Delivery 2 — Private demo Reacti for first-time users ⭐

**Wireframe:** every first-time user gets one harmless practice Reacti — "Tap when
you're ready" → it opens and records exactly like the real product → shows what a
friend would receive, **but is never sent** and stays on the phone.

- **NEW (M–L).** Nothing like this exists. This is the flagship activation build.
- **Why it's the top pick:** the loudest, most-repeated tester complaint (4 testers:
  Gon, Kobi, Jon + Tamar) is the empty home + "I don't know what to do". Triage #20
  rates this **highest leverage**. A **scripted demo** (fake friend, canned media,
  the real capture UI, nothing uploaded) gets ~90% of the value at a fraction of the
  cost of an AI coach.
- **Hard constraint (patent):** the demo must **reuse the real capture UI feel** but
  must **not** touch or fork the patented `recordVideoSilently()` / `mark-viewed` /
  reaction-upload path. The demo records locally and discards; it must be a clearly
  separate, non-sealing, non-uploading path so it can never leak a real reaction. Any
  work that comes near `receiver_message_widget.dart` re-runs the patent regression
  suite (CLAUDE.md north-star).
- **Feeds:** unlocks Delivery 1's "try it now" and the `demo_reaction_completed`
  event in Delivery 4's funnel.
- **DECISION D3:** scripted demo bot (recommended, cheap) vs. a fuller AI-style coach
  (much bigger). Default assumption for this plan: **scripted**.

**Verdict:** NEW (M–L). Sequencing anchor for onboarding + analytics.

---

## Delivery 3 — Sending flow + Message Preview

**Wireframe (4 steps):** obvious "send your first Reacti" → normal contact/group list
(no new picker) → paperclip → Gallery/Camera like WhatsApp → chat-list rows say
exactly what's inside ("New photo Reacti" / "New video Reacti · 0:24" /
"Reaction received") instead of "File attachment". Plus a BEFORE/AFTER chat-list page.

- **HAVE** — 2-option **Gallery/Camera picker** shipped to prod (PR #270/#277, per
  triage #9). Normal contact/group list exists. **Chat filters** (All / 1:1 / Groups /
  **Unseen** + badge) are on `develop` (PR #253). Empty state ("No Reactis yet / Send
  your first Reacti") exists.
- **HAVE (planned bigger)** — WhatsApp **multi-select + review screen** is its own
  approved plan (`PLAN-whatsapp-media-2026-07-16.md`), separate from this delivery.
- **GAP → the actual point of this page** — chat-list **preview labels**. Rows today
  render generic "File attachment"; the wireframe wants type-aware text: **"New photo
  Reacti"**, **"New video Reacti · 0:24"** (with duration), **"Reaction received"**.
  This is a **small, high-clarity** client change (chat-list row builder + a mapping
  from message type/media type → label; duration formatting for video). Not currently
  ticketed anywhere — this plan introduces it.

**Verdict:** flow HAVE; **preview labels = GAP (S)** and the real deliverable here.

---

## Delivery 4 — Beta analytics (activation funnel)

**Wireframe:** track the full loop — funnel Signup → Demo done → Invite sent → Reacti
sent → Delivered; core events `signup_completed`, `demo_reaction_completed`,
`invite_opened`, `reacti_sent`, `reaction_viewed`; "measure behaviour — never access
or analyse user media"; primary metric = % of new users who complete one full loop.

- **HAVE** — PostHog + Sentry analytics platform is **built and live in prod** (memory:
  analytics on in prod since 1.2.1; privacy-first: salted id, event allowlist, opt-out
  app+backend; existing dashboards). `reacti_sent` / `reaction_viewed`-type events and
  a message-received hook already exist.
- **GAP** — the specific **beta-activation funnel** view (as drawn) plus 1–2 events
  that only exist once their feature does: **`demo_reaction_completed`** (needs
  Delivery 2) and **`invite_opened`** (needs Delivery 5). `signup_completed` likely
  exists; confirm against `docs/analytics/` event catalog.
- **Rule** — new events follow the analytics **allowlist** rules in `docs/analytics/`;
  never send media or PII. The "never analyse user media" banner is already the
  platform's stance.

**Verdict:** infra HAVE; **funnel + 2 gated events = GAP (S)**, best finished *with*
#2 and #5 so the funnel is whole.

---

## Delivery 5 — Simple personal invite (share sheet + one-tap connect)

**Wireframe (5 steps):** non-Reacti contacts get an **Invite** button → tapping opens
the **standard iOS share sheet** with a prepared message (WhatsApp/Messages/Copy/Mail)
→ toast + row flips to "Invited" → after the invitee signs up they see **"Jon invited
you / Connect with Jon"** (one tap, never forced) → lands in Jon's chat with **"Send a
Reacti"** as the obvious next action.

- **PARTIAL / mostly NEW.** Contacts matching ("who's already on Reacti") and friend
  requests exist (`find_screen.dart`, search/request flow). The **share-sheet invite
  for non-users** and the **post-signup one-tap connect** do **not** exist.
- **Important distinction:** this is the **non-recording** invite — just sharing an
  install link with a prepared message. It is **NOT** the legally-blocked viral demo
  (`RESEARCH-BRIEF-viral-reaction-demo-2026-07-01.md`, triage #32 — that one records a
  non-user's camera and is on hold pending legal). Delivery 5 has **no legal blocker**.
- **NEW (M):**
  - Client: an **Invite** affordance on contacts not on Reacti → `share_plus`-style
    iOS share sheet with a prepared message + invite link; local "Invited" state +
    toast.
  - Backend + link: an **invite link that carries the inviter** so the invitee can be
    connected in one tap after signup. The "Connect with Jon" screen needs the invite
    context to survive install → first launch.
- **DECISION D4:** the one-tap connect needs a **deferred deep-link** mechanism
  (Branch / Adjust / Firebase Dynamic Links successor) to carry "who invited me" across
  the App Store install. Options: (a) paid provider (clean attribution), (b) simple —
  ship v1 with a plain App Store link + a manual "who invited you?" step, add deferred
  deep-linking later. Pick before building the connect half.

**Verdict:** invite button + share = NEW (M); one-tap connect = NEW gated on D4.

---

## Delivery 6 — Group react-to-unlock ⭐ DECISION

**Wireframe (2 steps):** in a group, "🔒 3 reactions waiting — reacting to the original
is the only way in"; you tap **Open and react**; once you react, **everyone else's
reactions unlock** (side-by-side list: Jon / Geoff / Lior).

- **NEW (M).** Not built. Triage #24: 🔴 Open, "Decide — I like it". Combines Jon's
  "react first to unlock" gate with Shai's "see all reactions side by side".
- **Why it's strong:** it's a genuine engagement mechanic (FOMO drives opens) and it
  fixes Jon's separate complaint that you can currently see others' reactions before
  sending your own. Very on-brand.
- **Scope:** a group message's other reactions stay **locked** until the viewer's own
  reaction is captured; then a **side-by-side reveal**. Touches group inbox rendering
  and the reaction-gating logic — near the patent flow, so it re-runs the patent
  regression suite and must not weaken the silent-capture guarantee.
- **Caution (from triage):** test that it doesn't frustrate people who just want to
  watch without reacting.
- **DECISION D1:** go / no-go on this behavior change. Default assumption for this
  plan: **build it**, but explicitly flagged.

**Verdict:** NEW (M), gated on D1.

---

## Delivery 7 — "How Reacti works" video on Profile

**Wireframe:** a Profile screen (avatar, Friends/Groups counts, Edit Profile, **How
Reacti works · Replay ▶**, Notifications, Privacy) — replay the onboarding anytime, no
digging into Settings.

- **GAP / small NEW (S).** Profile screen exists (`profile_screen.dart`). Missing: a
  **"How Reacti works" row with a Replay action** that re-opens the existing carousel
  (`OnBoardScreen`, reused read-only). This pairs directly with QW3's "re-openable
  carousel" work — same reusable entry point, second placement.
- Whether "Replay" opens the **carousel** or a future **onboarding video** depends on
  Delivery 1/2; for v1, reuse the carousel.

**Verdict:** GAP (S). Cheap; reuses the carousel.

---

## Delivery 8 — Later beta cleanup (3 items)

**Wireframe (3 steps):** (a) combine Friends + Requests into one **People** tab;
(b) a dedicated **Send Reacti** button + a visible attach icon (sending photo/video
obvious even from plain text); (c) ask for camera/mic permission **only when the
feature is used**, right at that moment.

- **8a — People tab: DECISION D2 (M).** Triage #21: 🟠 Partial. We **just** shipped a
  4-tab bar (Chat / Friends / Request / Profile, PR #252). Jon wants **3 tabs** (Chats /
  People / Profile) with Friends+Requests merged + a hero CTA. This **partly reverses
  the nav we just changed** — needs a decision (and ideally a design pass / A-B) before
  touching nav again. Default assumption: **hold; keep 4-tab for now.**
- **8b — Send Reacti CTA + visible attach icon: NEW (S–M).** Composer has attach today;
  a clear **"Send Reacti"** primary action + a visible attach affordance is missing.
  Overlaps triage #21's "obvious Send reacti button".
- **8c — Just-in-time camera/mic permission: NEW (S–M), overlaps EP4.** Today asks are
  abrupt (onboarding brief §2). The wireframe wants the OS prompt **at the moment** a
  Reacti is opened, with a friendly primer. `enhancement-plan.md` EP4 already lists
  "check camera/mic permission before recording" — this is the UX layer on top. Keep it
  **away from** the silent-capture internals; it's a pre-prompt, not a change to the
  capture itself.

**Verdict:** 8a = DECISION (M); 8b = NEW (S–M); 8c = NEW (S–M), coordinate with EP4.

---

## Summary table

| # | Delivery | State | Size | Blocker |
|---|----------|-------|------|---------|
| 1 | Onboarding carousel | HAVE + copy refresh GAP | S | — |
| 2 | Private demo Reacti | **NEW** ⭐ | M–L | D3 (scripted vs AI) |
| 3 | Sending flow | HAVE; **preview labels GAP** | S | — |
| 4 | Beta analytics funnel | infra HAVE; funnel + 2 events GAP | S | needs #2, #5 |
| 5 | Personal invite | **NEW** (no legal block) | M | D4 (deep-link) |
| 6 | Group react-to-unlock | **NEW** ⭐ | M | D1 (go/no-go) |
| 7 | "How Reacti works" on Profile | GAP | S | — |
| 8a | People tab merge | **DECISION** | M | D2 (nav) |
| 8b | Send Reacti CTA | NEW | S–M | — |
| 8c | Just-in-time permission | NEW (overlaps EP4) | S–M | — |

---

## Proposed build sequence (for discussion — not locked)

Each item = its own branch off `develop`, one concern per PR, tests-first where it
touches behavior, patent suite re-run on anything near the capture flow (per CLAUDE.md
and `enhancement-plan.md` rule 4).

**Wave 0 — near-free gaps (days):**
1. #3d chat-list **preview labels**.
2. #7 **"How Reacti works" replay** row on Profile (reuse carousel).
3. #1 carousel **copy refresh** to match the wireframe.

**Wave 1 — the flagship (the activation win):**
4. #2 **Private demo Reacti** (scripted), + its `demo_reaction_completed` event.

**Wave 2 — growth loop + measurement together:**
5. #5 **Personal invite** (share-sheet invite first; one-tap connect after D4).
6. #4 **Activation funnel** completed now that demo + invite events exist.

**Wave 3 — engagement mechanic (after D1):**
7. #6 **Group react-to-unlock** + side-by-side reveal.

**Wave 4 — cleanup (after the loop feels good):**
8. #8b **Send Reacti CTA** + visible attach icon.
9. #8c **Just-in-time permission** primer (coordinate with EP4).
10. #8a **People tab** — only if D2 says merge.

---

## Decisions to make before building (trim list here)

- **D1 — Group react-to-unlock (#6):** build it, or hold? _(Default: build.)_
- **D2 — People tab (#8a):** merge Friends+Requests into a 3-tab nav, or keep the
  current 4-tab bar we just shipped? _(Default: keep 4-tab for now.)_
- **D3 — Demo (#2):** scripted demo bot (cheap, ~90% of value) or fuller AI-style
  coach (much bigger)? _(Default: scripted.)_
- **D4 — Invite connect (#5):** paid deferred-deep-link provider for one-tap connect,
  or ship v1 with a plain App Store link and add deep-linking later? _(Default: plain
  link v1.)_
- **Also confirm:** the north-star activation metric for #1/#2/#4 (per the onboarding
  research brief) so the redesign is measured against something.

## Cross-references (so nothing gets rebuilt)

- Onboarding depth + coach-mark: `RESEARCH-BRIEF-onboarding-and-first-use-2026-07-01.md`
- Media multi-send (separate from #3): `PLAN-whatsapp-media-2026-07-16.md`
- Quick-wins incl. "return to intro" (QW3): `PLAN-quick-wins-tester-feedback-2026-07-14.md`
- Nav history (4-tab decision): `PLAN-ux-fixes-2026-06-28.md`, triage #21
- Viral demo (the legally-blocked cousin of #5): `RESEARCH-BRIEF-viral-reaction-demo-2026-07-01.md`
- Permission/patent hardening (#8c): `enhancement-plan.md` EP4
- Full tester map: `FEEDBACK-triage-2026-07-14.md`
