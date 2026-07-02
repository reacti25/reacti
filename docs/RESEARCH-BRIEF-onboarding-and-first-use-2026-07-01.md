# RESEARCH BRIEF — Onboarding & first-use guide

**Date:** 2026-07-01
**Author:** Achia (goals) + Claude (research plan)
**Status:** Research / design brief. **Not** an implementation plan yet — the output
of this work is a UX brief + mockups + a `PLAN-*.md` that Claude Code can then build.
**Covers:** Achia's feature-list items **2** ("explore the onboarding, make it as
simple and good-looking as possible") and **4** ("make the first-time guide simple,
good-looking, explain the most important thing"). These are one effort.

---

## 1. Why this needs research (not just building)

The two easy items (theme, media picker) have a single correct answer. Onboarding
does not: "good-looking and simple" is a design + activation problem, and the highest-
leverage change might be one that isn't obvious yet. We should **measure and study
before redesigning**, or we risk polishing the wrong screen.

There is also a subtlety unique to Reacti: the core mechanic (your front camera
silently records your reaction when you open media) is **surprising and needs
explaining**, but explaining it badly could feel creepy and scare new users off. The
first-use guide is where we make that feel delightful instead of alarming. This must
stay consistent with the recording-consent work (see
`docs/PLAN-dg1-consent-flow-2026-06-12.md` and
`docs/BRIEF-recording-consent-at-signup-2026-07-01.md`) — the *guide* explains the
feature; the *consent* step authorises it. Keep them aligned, don't merge them.

---

## 2. What exists today (baseline)

- **Pre-signup carousel already exists:**
  `app/lib/features/onboard/presentation/on_board_screen.dart` — a 3-slide
  `PageView` with `smooth_page_indicator`, Skip + Next/Get Started:
  1. "Share Authentic Moments"  2. "Your Privacy Matters"  3. "Reaction to View".
  First-run routing: `app/lib/loading.dart` reads `kKeyIsFirstTime` → `OnBoardScreen`
  → on finish sets `kKeyIsFirstTime = false` → `LoginScreen`.
- **No in-app coaching exists.** There are no coach-marks, tooltips, or first-message
  guide. A brand-new user is never shown *how* the reaction mechanic works inside the
  app — they have to discover "tap the blurred thing" on their own.
- **No onboarding/coach-mark package** in `pubspec.yaml` (only `smooth_page_indicator`).
- Permission asks today are abrupt: e.g. the Friends tab auto-fires the OS contacts
  prompt (being addressed separately in `docs/PLAN-ux-fixes-2026-06-28.md` Phase 5).

So this is a **redesign + fill-the-gap**, not a greenfield build. The biggest missing
piece is almost certainly the **in-app first-message coach-mark**, not the carousel.

---

## 3. The two surfaces to design (keep them distinct)

1. **Pre-signup value carousel** — "what is Reacti and why do I want it." Exists;
   redesign for clarity + polish. Fewer, sharper slides; strong single value prop.
2. **In-app first-use guide** — the *first time* a user encounters a blurred message
   (and/or sends their first one), a lightweight coach-mark: "Tap to reveal — and your
   reaction is captured and sent back. That's Reacti." This is the missing, high-
   leverage surface.

A third, supporting surface: **permission priming** — friendly soft-ask screens
*before* the OS prompts for camera, notifications, and contacts, explaining why.

---

## 4. How to research it

### 4.1 Measure first (know where users actually drop)

- Use the existing **PostHog** analytics (see `docs/analytics/`) to build a first-run
  **activation funnel**: install → onboarding complete → signup start → OTP verified →
  consent granted → first friend added → first media sent → **first reaction sent**
  (the real "aha"). Find the biggest drop-off. Redesign *that* step first.
- If the events for these steps don't exist yet, adding them is prerequisite work
  (small, additive; follow the analytics allowlist rules in `docs/analytics/`).
- Define the **north-star activation metric** up front, e.g. "% of new installs that
  send or receive their first reaction within 24h." Everything is judged against it.

### 4.2 Competitive teardown (study, don't copy)

Install and screen-record the first-run of:

- **BeReal** — closest analog: "authentic moment," dual-camera, permission priming.
  Study how they explain a surprising camera behaviour without being creepy.
- **WhatsApp** and **Telegram** — the simplicity/polish bar; how minimal onboarding can
  be; permission timing.
- **Snapchat / Locket** — playful camera-first onboarding and friend-add loops.

For each capture: number of screens, order of permission asks (and whether soft-asked
first), how/when the core mechanic is taught, copy tone, and the very first action
they push you toward. Summarise into a one-page teardown.

### 4.3 Design the copy + flow, then mock it up

- Draft the **carousel copy** (3 slides max, one idea each; lead with the reaction
  hook, then privacy/friends-only, then a clear CTA).
- Draft the **first-message coach-mark** copy — short, warm, sets the expectation that
  a reaction will be recorded (ties to consent, so the user isn't surprised).
- Produce **mockups**: Claude can generate wireframes and an interactive HTML
  prototype of the flow for review; a designer then polishes in Figma. Match the app's
  visual language (lime `allPrimaryColor`, dark base, and now light mode from
  `PLAN-theme-and-media-picker-2026-07-01.md`).

### 4.4 Pick the implementation mechanism

- Evaluate coach-mark packages: **`showcaseview`** and **`tutorial_coach_mark`** vs a
  small custom overlay. Criteria: RTL support (Hebrew), one-time-only display
  (persist a `kKeyGuideSeen`-style flag in GetStorage), and not fighting the existing
  `PageView`/GetX/provider setup.
- Confirm the carousel can be refreshed in place (it's already custom) rather than
  swapping in a new package.

---

## 5. Deliverables of this research

1. A one-page **activation-funnel** read from PostHog with the biggest drop-off named.
2. A one-page **competitive teardown**.
3. **Copy deck** (carousel + coach-mark + permission priming).
4. **Mockups / interactive prototype** of the redesigned flow.
5. A follow-up **`PLAN-onboarding-*.md`** (Claude Code-ready, phased, with verification
   checklists) — the actual build plan.

---

## 6. Open questions for Achia

- Is there budget/appetite for a **designer** to polish, or should we ship a
  Claude-designed flow and iterate?
- Do we want the coach-mark on the **first received** blurred message, the **first
  sent** media, or both?
- How aggressively do we want to teach the reaction mechanic up front vs. let people
  discover it? (Trade-off: clarity/activation vs. surprise/delight.)
- Confirm the **north-star activation metric** so we can measure the redesign.

---

## 7. Key files index

- `app/lib/features/onboard/presentation/on_board_screen.dart` — existing carousel.
- `app/lib/loading.dart` — first-run routing (`kKeyIsFirstTime`).
- `app/lib/constants/app_constants.dart` — GetStorage keys (add a guide-seen flag).
- `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` — where the
  first-message coach-mark would attach (read-only w.r.t. the patent flow behaviour).
- `docs/analytics/` — event catalog + PostHog dashboards for the funnel.
- Related: `docs/PLAN-dg1-consent-flow-2026-06-12.md`,
  `docs/BRIEF-recording-consent-at-signup-2026-07-01.md`,
  `docs/PLAN-ux-fixes-2026-06-28.md` (Phase 5 contacts priming — coordinate).
