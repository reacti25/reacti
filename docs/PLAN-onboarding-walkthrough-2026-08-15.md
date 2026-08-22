# PLAN — In-app "how to use Reacti" tour (replaces the carousel) — 2026-08-15

**Status: PROPOSAL. Nothing built. Awaiting Achia's decisions (§6).**

Ask (Achia, 2026-08-15): a first-run walkthrough **inside the app itself**, the
way Tinder/OkCupid do it — *"an intro to using the app in general"*. Explicitly
**not** the Demo Reacti: that one is about the product idea and exists to make
new users *want* Reacti. This is the practical one — where things are and how to
do them. It replaces the pre-login carousel.

---

## 1. What exists today, and why it doesn't cover this

| Surface | When | Teaches | Verdict |
|---|---|---|---|
| **Carousel** (`on_board_screen.dart`) | Before login | 3 static slides of stock art: "Share Authentic Moments" / "Your Privacy Matters" / "Reaction to View" | **Replace.** Pre-login, generic, no interaction, teaches nothing operational |
| **Demo Reacti** (`demo_reacti_screen.dart`) | First entry after signup | The *idea*: a sealed clip → you open it → your real reaction is captured → reveal | **Keep as-is.** This is the allure piece, and it works (signed off 2026-07-22) |
| **Appearance picker** | First entry, after the demo | Light/dark | Keep |

Nothing anywhere teaches: what the four tabs are, how to add a friend, how to
invite someone, how to start a chat, or how to send a photo. A new user finishes
the demo understanding *why* Reacti is good and not *how to do anything*.

## 2. The one real design constraint

Tinder can spotlight a card because its first screen is already full. **A brand
new Reacti account is empty** — no chats, no friends, no requests.

The way through: **point at controls, not content.** The bottom-nav tabs, the
new-chat button, the invite button and the composer's attach icon all exist on
an empty account. A tour built around those works on day one; a tour that wants
a chat bubble to point at does not.

This also argues against one long upfront tour: the composer only exists once
you are *inside* a chat, which a new user isn't yet.

## 3. Recommended shape: a short home tour + just-in-time marks

**Not** a 6-step sequence up front (nobody remembers step 5 by the time it's
relevant). Instead:

**(a) Home tour — 3 marks, immediately after the demo, on the real home screen**

1. **Chat tab** — "Your conversations live here."
2. **Friends tab** — "Add friends, or invite people who aren't on Reacti yet."
3. **New chat button** — "Start a chat here."

Dimmed overlay, cut-out around the real control, one line of copy, Next / Skip.
~20 seconds total.

**(b) Just-in-time marks — one per screen, the first time you land there**

| Trigger | Mark |
|---|---|
| First time the Friends tab opens | the invite button — "Nobody here yet? Invite a friend." |
| First time a chat thread opens | the attach icon — "Send a photo or video — that's a Reacti." |
| First time a group is opened (optional) | the reactions strip |

Each fires once, keyed in `GetStorage` next to the existing `kKeyDemoSeen` /
`kKeyIsFirstTime` flags. This is the pattern that actually teaches: the tip
arrives at the moment it's usable, on a screen that finally has something on it.

**Order relative to the demo:** demo first (the idea), then the home tour (the
mechanics). The demo already runs from `NavigationScreen.initState`; the tour
hooks the same place, after the demo returns.

## 4. Proposed build

One branch/PR per phase, per repo convention.

### T1 — Spotlight overlay + one-time flags · `feat/tour-overlay` · M

The mechanism, with a single throwaway mark to prove it: dimmed barrier, cut-out
around a target `GlobalKey`'s rect, caption card that flips above/below the
target near screen edges, Next/Skip, and a `TourStep` list so adding a mark is
one entry.

**Dependency decision (O2).** Options:

* **`showcaseview`** — pure Dart, no native code, so it sidesteps the CI
  Xcode/iOS-SDK trap that bit `connectivity_plus`. Handles cut-out, positioning
  and sequencing. ~1 day saved.
* **Hand-rolled** (~200 lines): `Stack` + `CustomPainter` cut-out +
  `GlobalKey` → `RenderBox` rects. No new dependency, and full control of the
  look, but edge-positioning and scroll are the fiddly parts.

Recommendation: **`showcaseview`**. This is past the "a few lines would do it"
line, and it's pure Dart so the usual native-plugin risk doesn't apply.

### T2 — Home tour (3 marks) · `feat/tour-home` · S–M

Wire the three marks above into `navigation_screen.dart`, fired after the demo,
gated on a new `kKeyTourSeen`. Skip on any step marks the whole tour seen.

### T3 — Just-in-time marks · `feat/tour-contextual` · M

Friends-tab invite mark and chat-thread attach mark, each with its own one-time
key. Cheap individually; the work is threading a `GlobalKey` to each target
without disturbing those widgets.

### T4 — Retire the carousel · `feat/retire-onboarding-carousel` · S

* Delete `OnBoardScreen`; `kKeyIsFirstTime` routes straight to login/signup.
* Keep **one** pre-login screen (O3): a single value line — "See a friend's real
  reaction the moment they open your photo" — plus **Get started**. That line is
  already proven on the web invite landing.
* Profile's **"How Reacti works"** row currently replays the carousel. Re-point
  it, and add **"How to use Reacti"** to replay this tour (O5).

## 5. Knock-on effects

* **F1 is superseded.** The last open wireframe item was the carousel copy +
  **three images you were going to shoot**. If the carousel goes, **those images
  are no longer needed** and that blocker disappears (O4).
* **Patent flow untouched.** This adds an overlay above existing screens; it does
  not go near blur/unblur, `recordVideoSilently()`, `mark-viewed` or reaction
  upload. Run the patent suite before merge anyway, per CLAUDE.md.
* **Analytics:** add `tour_started`, `tour_step_seen` (with step name),
  `tour_skipped`, `tour_completed`. Drop-off per step tells you which mark is
  wasted — the funnel already exists (PostHog dashboard 848115).
* **Tests:** each mark needs its one-time key asserted (shows once, never again)
  and a skip test. Note the existing gotcha — tests that touch storage-gated
  first-run paths need `initTestGetStorage()`, which caught 5 tests during F8c.

## 6. Decisions — LOCKED (Achia, 2026-08-15: "start with your recommendations")

| # | Decision | Locked answer |
|---|---|---|
| **O1** | Tour shape | **Short home tour (3 marks) + just-in-time marks.** No long upfront sequence |
| **O2** | Overlay implementation | **`showcaseview`** — pure Dart, no native code |
| **O3** | Carousel | **Keep one pre-login value line + Get started**; the 3-slide carousel goes |
| **O4** | F1's three carousel images | **No longer needed** — that blocker is closed |
| **O5** | Replay | **Profile row "How to use Reacti"** |
| **O6** | Marks | **5 total** — 3 home + 2 contextual |

**Phase change:** T1 and T2 ship as one PR. T1 was scoped as "the mechanism plus
a throwaway mark to prove it" — with `showcaseview` supplying the mechanism,
a proving phase is dead weight; the home tour proves it.

## 7. Estimate

T1 ~1 day (half that with `showcaseview`), T2 ~half a day, T3 ~1 day,
T4 ~half a day. **~2.5–3 days**, plus a staging build and your on-device pass
per phase, as usual.
