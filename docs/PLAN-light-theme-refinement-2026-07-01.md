# PLAN — Light theme refinement: depth, warmth, and the last invisible text

**Date:** 2026-07-01
**Author:** Achia (direction) + Claude (research + design)
**For:** Claude Code
**Status:** Approved refinement. Builds directly on
`docs/PLAN-light-theme-color-system-2026-07-01.md` (the token system, which worked).
This is a **tuning pass on the token values + two bug fixes**, not a rebuild. Confirm
with Achia before starting, per `CLAUDE.md`.
**Screenshots:** `docs/screenshots/light-theme-v3-2026-07-01/`.

---

## 0. Where we are

The token system landed and the app is now cohesive in Light — Profile, chat list,
inbox, requests, settings all re-theme correctly (round-3 screenshots `01`–`05`, `07`,
`09`, `12`). Two problems remain:

- **Problem A — the theme looks flat / washed-out / "lifeless."** The canvas
  (`~#F2F2F7`) and the white cards are almost the same lightness, and there are **no
  shadows**, so cards don't separate from the background. Everything sits at ~92–100%
  lightness with nothing to anchor the eye. (Every "ok" screenshot shows this.)
- **Problem B — a few screens still have near-white text on the pale background**, so it's
  invisible: "No blocked users found" (`06`), the "Appearance" screen title (`08`), and
  on Sent Requests both the title and "You haven't sent any request" (`11`). These are
  leftover hardcoded white / dark-mode-only text colours.

This plan fixes both.

---

## 1. What the research says (how to add depth without going dark)

From Material 3's tone-based surfaces and light-theme design guidance (see References):

1. **Don't rely on one near-white plane.** Avoid pure `#FFFFFF` as the whole canvas; use
   a **layered neutral ramp** — a deeper background tone with **lighter cards on top**.
   The tonal *step* between background and card is what creates depth.
2. **Combine tonal + shadow elevation.** Start with the tonal step, then add a **soft
   shadow** on cards/sheets/nav for separation. Use a **tinted shadow** (a dark version of
   the background colour), **not pure black** — pure-black shadows on a coloured surface
   look dull/dirty.
3. **A slightly warm neutral feels more alive** than a cool blue-grey (the current
   `#F2F2F7` reads cool/clinical). A warm greige harmonises with Reacti's lime brand.
4. **Give text real contrast.** Primary near-black; secondary a true mid-grey (not pale),
   so content has weight.

Net: make the **canvas a bit deeper and warmer**, keep **cards near-white**, add **soft
tinted shadows**, and **strengthen text**. Still clearly a light theme — just with depth.

---

## 2. Revised token values (this is the core change)

Replace the light values from the previous plan with a **3-step neutral ramp + shadow**.
Dark mode is unchanged. Recommended = **warm**; a cool alternative is listed so Achia can
pick after seeing it.

### 2.1 Neutral ramp (light)

| Token | Recommended (warm) | Cool alternative | Role |
|---|---|---|---|
| `canvas` (scaffold background) | **#EAE8E3** | #E7E8EB | Deeper than before → cards separate. The "a bit darker but still bright." |
| `card` (cards, rows, app bar, nav, sheets, incoming bubble) | **#FFFFFF** (or warm #FDFDFB) | #FFFFFF | Sits above canvas; gets a shadow. |
| `sunken` (inputs/wells inside white cards) | **#F1EFEA** | #F0F1F4 | Slightly recessed vs the white card. |
| `hairline` (dividers/borders) | **#DEDCD6** | #DADBDF | A touch stronger than before. |
| `textPrimary` | **#161513** | #141518 | Near-black, slight warmth. |
| `textSecondary` (subtitles, timestamps, section headers, empty states) | **#5F5D57** | #5C5F66 | A true mid-grey — NOT pale. |
| `textTertiary` / placeholder | **#8B897F** | #8A8D94 | Hints only. |

### 2.2 Elevation (new — add this)

- **Card shadow:** color = **rgba(50,46,36,0.10)** (warm) / rgba(30,33,40,0.10) (cool),
  offset y ≈ 2, blur ≈ 12, spread 0. Subtle, soft. Apply to conversation rows, settings
  cards, request/friend cards, sheets, dialogs.
- **Bottom nav / app bar:** a very soft top/bottom shadow (same colour, blur ≈ 8, ~0.06)
  **or** a `hairline` divider — enough to detach it from the canvas.
- Keep it gentle: one elevation level for cards, one for nav/sheets. Don't over-shadow.

### 2.3 Brand + bubbles + status (unchanged from the previous plan, keep)

`brandFill` #DCFC53 (dark text on it), `brandAccent` #4F5E00 (text/icons on light),
`bubbleIn` #FFFFFF, `bubbleOut` #E7F59C, `chatBackground` = `canvas`, `error` #D64B3F,
switch on-track = `brandFill`. Avatar placeholder bg = `sunken`, glyph = `textTertiary`.

> Values are tunable; keep the **relationships** (canvas darker than card; secondary text
> a real mid-grey; shadows tinted). Achia to confirm warm vs cool after a build.

---

## 3. Problem B — fix the invisible text (bugs)

These screens render text in white / a dark-mode-only colour. Route them to tokens:

- **`06` "No blocked users found"** — the blocked-users **empty-state** text is white →
  set to `textSecondary`. Find the blocked-users screen's empty state.
- **`11` Sent Requests** — BOTH the **screen title** ("Sent Requests") and the
  **empty-state** ("You haven't sent any request") are white. Title → `textPrimary` via
  AppBarTheme (this screen is likely setting its own white title, or using a custom header
  — make it use the themed AppBar/title colour); empty state → `textSecondary`.
- **`08` Appearance** — the **"Appearance" screen title** is white/ghosted → `textPrimary`
  via AppBarTheme. (The System/Light/Dark rows are fine.)
- **Sweep for the pattern:** grep the codebase for empty-state widgets and screen
  titles/headers still using `Colors.white`, `AppColors.cFFFFFF`, or a dark-only text
  constant. Any "No X found" / "You haven't…" empty state and any custom screen header is
  a suspect. Route them all to `textPrimary` (titles) / `textSecondary` (empty states).
  There are likely a few more empty states not screenshotted (e.g. empty chat list, empty
  search, empty friends) — fix them the same way.

> These are the same class of bug as the earlier invisible titles: text colour pinned to
> white instead of a token. The token system fixes most; these screens bypassed it.

---

## 4. Implementation steps (one branch: `fix/app-light-theme-refinement`)

1. Update the light neutral tokens in `app/lib/theme/app_theme.dart` to the §2.1 ramp
   (canvas deeper+warmer, stronger secondary text, hairline).
2. Add **elevation**: a card shadow style + apply to cards/rows/sheets/nav; soft
   separation on app bar + bottom nav (§2.2). Put the shadow in the shared card/theme so
   it's consistent, not per-screen.
3. Fix the invisible-text screens and sweep empty-states/titles to tokens (§3).
4. Re-verify the previously-good screens still look right with the deeper canvas (cards
   should now visibly "pop").
5. Keep **Dark mode pixel-identical**. `flutter analyze` + `dart format .` clean.

Small, focused branch on top of the token system — mostly value changes + one shadow
style + a handful of text-colour fixes.

---

## 5. Definition of done

1. **Depth:** cards, conversation rows, and settings cards visibly separate from the
   canvas (tonal step + soft shadow). The app no longer looks flat/washed-out.
2. **Warmth/tone:** canvas is a soft, slightly-deeper neutral (not blinding near-white,
   not cool-clinical). Achia has confirmed warm vs cool.
3. **No invisible text anywhere:** every screen title and every empty-state message is
   legible (WCAG AA). Specifically `06`, `08`, `11` fixed, plus any other empty states.
4. **Text has weight:** secondary text is a real mid-grey, not pale.
5. **Shadows are tinted, subtle, consistent** (not pure-black, not heavy).
6. Brand, bubbles, nav, inputs still correct from the previous plan.
7. **Dark mode unchanged.** Patent flow untouched; regression test green. RTL intact.

---

## 6. Verification

- Walk every screen in Light and screenshot. Confirm: (a) cards clearly lift off the
  canvas; (b) no white-on-pale text — check every **empty state** (blocked users, sent
  requests, empty chat list, empty search, empty friends/contacts) and every **screen
  title**; (c) it feels calm and substantial, not washed-out.
- Side-by-side the "ok-but-flat" round-3 shots (`02`, `03`, `12`) before/after to confirm
  the depth improvement.
- Contrast-check: `textSecondary` on `card` and on `canvas`; empty-state text on `canvas`;
  title on app bar. All ≥ 4.5:1.
- Dark mode spot-check unchanged. Update the golden tests to the new light values.

---

## 7. Key files index

- `app/lib/theme/app_theme.dart` — neutral ramp, shadow/elevation style, `ReactiColors`
  values (the change hub).
- Blocked-users screen (empty state), Sent Requests screen (title + empty state),
  Appearance screen (title) — the three invisible-text fixes; plus any other empty-state
  widgets found in the sweep.
- Bottom nav: `app/lib/features/navigation/presentation/navigation_screen.dart`
  (soft separation).
- Builds on `docs/PLAN-light-theme-color-system-2026-07-01.md`; supersedes its light
  neutral values.

---

## 8. References

- Material 3 — tone-based surfaces & applying elevation (tonal + shadow to create depth):
  m3.material.io ("Learn About Tone-based Surfaces", "Applying elevation").
- Light-theme design guidance — avoid pure white, use soft neutrals (#F4F6F8 / #F9FAFB
  family), tinted (not black) shadows, combine tonal + shadow elevation.
- Prior refs carried from the color-system plan (iOS grouped backgrounds, WhatsApp).
- Source links are in the chat message accompanying this doc.
