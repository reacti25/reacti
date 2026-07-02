# PLAN — Light theme done right: a semantic colour system

**Date:** 2026-07-01
**Author:** Achia (direction) + Claude (research + design)
**For:** Claude Code
**Status:** Approved approach. Supersedes the piecemeal fixing in
`docs/BUG-light-theme-incomplete-2026-07-01.md`. Build it as **one coherent theming
pass**, then verify every screen. Confirm with Achia before starting, per `CLAUDE.md`.
**Screenshots:** `docs/screenshots/light-theme-v2-2026-07-01/` (round-2 state).

---

## 0. Why the first two attempts failed (read this first)

Both previous attempts fixed **screens one at a time** and only where text was
obviously invisible. That's why the result is a patchwork: the settings screens got
fixed, but the **Profile screen is still fully dark**, the **chat-list cards and filter
chips are still dark**, the **inbox loses the contact's name and keeps a dark composer**,
and a **soft screen is still blank white**. See round-2 screenshots `09`, `10`, `11`, `05`.

The root problem is architectural, not cosmetic:

1. **There is no single colour system.** Widgets read fixed colours
   (`Colors.white`, `Colors.black`, dark-only `AppColors.cXXXXXX`) instead of
   **semantic tokens** that resolve differently per mode. So each screen has to be
   hand-fixed, and any screen nobody looked at stays dark.
2. **Pure white was used as the canvas.** Real apps don't. iOS's grouped style and
   WhatsApp use a **soft off-white canvas with white cards on top** — that's the "bright,
   but not exactly white" look Achia asked for. Pure white also makes the lime brand
   colour look harsh.
3. **The lime brand colour was reused as-is.** Lime (`#DCFC53`) is designed to glow on a
   dark background. On white it fails contrast for text/icons. It needs **two roles**: a
   *fill* (lime block with dark text) and an *on-light accent* (a darkened brand colour
   for text/icons/active states).

**The fix:** define one semantic token set with a light and a dark value for every role,
theme all shared Material components once, add a `ThemeExtension` for the
messaging-specific colours Material doesn't cover (bubbles, brand roles), then delete
hardcoded colours so **every** screen — including ones we didn't screenshot — inherits
the right look automatically.

---

## 1. Design principles (the model to copy)

Grounded in how iOS system apps and WhatsApp build their light theme (see References):

1. **Layered neutrals, not flat white.** A **soft off-white canvas** (`~#F2F2F7`) with
   **white cards/rows** on top. The gentle contrast between canvas and card is what makes
   lists, chat rows, and settings groups read as distinct — without borders everywhere.
   (iOS: `systemGroupedBackground #F2F2F7` behind `secondarySystemGroupedBackground
   #FFFFFF`.)
2. **Semantic text tokens, not greys.** Primary / secondary / tertiary text with fixed
   meanings and guaranteed contrast (iOS `.label` #000, `.secondaryLabel` ~#3C3C43 @60%).
3. **Brand as accent, tuned per background.** Lime stays the identity, but on light
   surfaces text/icons use a **darkened brand** so they're legible; lime is reserved for
   **fills** (buttons, selected pills) with dark text on top.
4. **Message bubbles are their own tokens.** Incoming = white/near-white; outgoing = a
   pale brand tint — both with dark text. (WhatsApp: incoming white, outgoing light green
   `#D9FDD3`.) The chat background is the off-white canvas, never pure white.
5. **Everything themed, nothing hardcoded.** Cards, app bars, the **bottom nav**, sheets,
   inputs, chips, switches, dividers, avatars, composer — all from tokens.
6. **Dark mode stays exactly as it is today.** It already looks right (round-2 chat list
   `09` and profile `11` are the correct dark look). We only add the light values.

---

## 2. The token system (single source of truth)

Author this in `app/lib/theme/` as the one place colours are defined. Two layers:

**Layer A — Material `ColorScheme` + component themes** (covers most widgets for free).
**Layer B — a `ThemeExtension` `ReactiColors`** for roles Material has no slot for
(brand fill vs brand accent, chat bubbles, canvas vs card, hairline, avatar placeholder).

### 2.1 Semantic tokens — light vs dark values

| Token (semantic role) | Light | Dark (keep = today) | Notes |
|---|---|---|---|
| `canvas` (scaffold background) | **#F2F2F7** (or warm-neutral #F4F5F2) | #010101 / #000000 | Never pure white in light. |
| `card` (rows, cards, app bar, nav bar, sheets) | **#FFFFFF** | #1C1C1E / #242424 | Sits on canvas. |
| `surfaceVariant` (inputs, unselected segment/chip, disabled) | **#ECEEF0** | #242424 / #333333 | Subtle fill. |
| `textPrimary` | **#0B0B0C** | #FFFFFF | Titles, names, body. |
| `textSecondary` | **#667781** | rgba(white,0.70) | Subtitles, timestamps, "Start Conversation…". |
| `textTertiary` / placeholder | **#9AA0A6** | rgba(white,0.40) | Hints, "Type a message…". |
| `hairline` (divider/border) | **#E4E6EA** | #2A2A2E | 1px separators. |
| `iconPrimary` | **#1A1A1A** | #FFFFFF | Default icons (back, gear, kebab). |
| `brandFill` (buttons, selected pill/chip, switch-on track, FAB) | **#DCFC53** | #DCFC53 | Lime block. |
| `onBrandFill` (text/icon on lime) | **#1A1A1A** | #1A1A1A | Dark on lime — passes AA. |
| `brandAccent` (active tab icon+label, links, wordmark, send icon) | **#4F5E00** | #DCFC53 | **Darkened lime for light** so it's legible on white; lime in dark. |
| `bubbleIn` / `onBubbleIn` | **#FFFFFF** / **#0B0B0C** | #242424 / #FFFFFF | Incoming, + `hairline` border in light. |
| `bubbleOut` / `onBubbleOut` | **#E7F59C** / **#1A1A1A** | current lime-ish / current | Outgoing = pale lime tint. |
| `chatBackground` | **#F2F2F7** (or subtle pattern) | current dark | Not pure white. |
| `avatarPlaceholder` bg / glyph | **#E4E6EA** / **#9AA0A6** | #333333 / #8A8A8A | White circles vanish on white — fix. |
| `error` / denied | **#E0483D** | current red | Red is fine on white; keep. |
| `switchOffTrack` / `thumb` | **#E4E6EA** / **#FFFFFF** | current | On-track = `brandFill`. |

> Exact hexes are a starting point tuned to the references; Achia can nudge `canvas`
> (cool #F2F2F7 vs warm #F4F5F2), `brandAccent` depth, and `bubbleOut` tint. Keep the
> **roles** fixed even if values are tweaked.

### 2.2 Map to Flutter `ColorScheme` (light)

Critical nuance so Material's own defaults are legible:

- `primary` = **`brandAccent` #4F5E00** (NOT lime) → Material-drawn accents/text default
  to the legible dark-brand, not lime-on-white.
- `onPrimary` = #FFFFFF.
- `primaryContainer` = **`brandFill` #DCFC53**, `onPrimaryContainer` = #1A1A1A → the lime
  block for filled buttons/selected states.
- `surface` = `card` #FFFFFF, `onSurface` = `textPrimary` #0B0B0C.
- scaffold / lowest containers = `canvas`; `surfaceContainerHighest` = `surfaceVariant`.
- `outlineVariant` = `hairline` #E4E6EA; `outline` = #C6C8CC.
- `error` = #E0483D, `onError` = #FFFFFF.

Dark `ColorScheme` = today's values (here `primary` = lime, since the background is dark).

### 2.3 `ThemeExtension` — `ReactiColors`

Add fields for everything `ColorScheme` can't express: `brandFill`, `onBrandFill`,
`brandAccent`, `canvas`, `card`, `bubbleIn`, `onBubbleIn`, `bubbleOut`, `onBubbleOut`,
`chatBackground`, `hairline`, `avatarPlaceholderBg`, `avatarPlaceholderGlyph`,
`textSecondary`, `textTertiary`, `iconPrimary`. Provide `ReactiColors.light` and
`ReactiColors.dark`, register both on the respective `ThemeData`, and read via
`Theme.of(context).extension<ReactiColors>()!`. Widgets use these instead of `AppColors`
wherever a colour must flip.

---

## 3. Component theming (do this once, in `app_theme.dart`)

Set these in both light and dark `ThemeData` so most screens are correct with no
per-widget work:

- **AppBarTheme** — bg `card`, foreground `iconPrimary`, title `textPrimary`, hairline
  bottom border, correct `SystemUiOverlayStyle` (dark status-bar icons in light).
- **Scaffold** background = `canvas`.
- **CardTheme / Container conventions** — `card` bg, `hairline` border, consistent radius.
- **BottomNavigationBar / NavigationBar** — bg `card`, selected `brandAccent`,
  unselected `textSecondary`. (Fixes the profile-vs-nav mismatch.)
- **InputDecorationTheme** — filled `surfaceVariant`, hint `textTertiary`, text
  `textPrimary`, focus border `brandAccent`.
- **SwitchTheme** — on-track `brandFill`, thumb white/`onBrandFill`, off-track
  `surfaceVariant`. (Fixes the muddy-olive toggle.)
- **SegmentedButton / ToggleButtons / chips** — unselected `surfaceVariant` +
  `textPrimary`; selected `brandFill` + `onBrandFill`. (Filter chips, Friends/Contacts.)
- **ElevatedButton/FilledButton** — `brandFill` bg, `onBrandFill` label.
- **TextButton / links** — `brandAccent`.
- **DividerTheme** — `hairline`.
- **DialogTheme / BottomSheetTheme** — `card` bg (incl. the media picker sheet).
- **Text theme** — primary/secondary/tertiary wired to the tokens.

---

## 4. Screen-by-screen fixes (from round-2 screenshots)

Most of these should fall out of Sections 2–3. Explicitly verify each:

**`11-profile-still-dark.png` — Profile (BROKEN, top priority).** The whole screen is
still dark (dark gradient background + dark cards), only the nav bar went white. The
background/gradient and cards are hardcoded dark. Re-theme: `canvas` background (drop or
recolour the dark gradient for light), `card` rows, `textPrimary`/`textSecondary`, section
headers ("ACCOUNT", "PRIVACY & SECURITY") in `textSecondary`, row icons `iconPrimary`,
chevrons `textTertiary`. Result must match the cohesion of the settings screens.

**`09-chat-list-cards-still-dark.png` — Chat list (BROKEN).** Canvas is white but the
conversation **cards are dark** and the **filter chips (1:1/Groups/Unseen) are dark**;
avatars are white circles (invisible on white). Fix: cards → `card` on `canvas`; names
→ `textPrimary`; "Start Conversation…" → `textSecondary`; chips via the chip theme
(selected `brandFill`/`onBrandFill`, unselected `surfaceVariant`/`textPrimary`); avatar
placeholder → `avatarPlaceholder`; the "Reacti" wordmark + top `+`/search icons →
`brandAccent` (lime-on-white is too faint).

**`10-inbox-name-missing-composer-dark.png` — Inbox / conversation (BROKEN).**
(a) The **contact's name is invisible** in the app bar (white on white) → app-bar title
`textPrimary` via AppBarTheme. (b) The **message area is blank** → message **bubbles**
must use `bubbleIn`/`bubbleOut` tokens with dark text; set the **chat background** to
`chatBackground` (off-white), not white. (c) The **composer bar is hardcoded dark** →
re-theme to `card`/`surfaceVariant` with `textTertiary` hint, `iconPrimary` attach, and
`brandAccent` send icon. **This is adjacent to the patent media/blur flow — do NOT change
its behaviour; only swap colour tokens, and keep the patent regression test green.**

**`05-blank-screen-STILL-BROKEN.png` — a fully blank white screen.** Identify which
screen (likely Terms/Privacy content or an empty-state). Its text is white-on-white or
its content is empty. Give it `textPrimary` copy on `canvas`; if it's an empty state, add
a proper empty-state (icon + `textSecondary` message).

**`02-privacy-policy.png` — Privacy Policy shows "No description."** Themed fine, but the
body content is missing (a data/content issue, not colour). Flag to Achia; out of scope
for the theme pass unless it's a trivial fix.

**Already acceptable (verify only):** Permissions List `01`, Usage Data `03`, Read
Receipts `04`, Change Password `06`, Requests `07`, Friends/Contacts `08`. Re-confirm they
still look right once the global token system replaces their local fixes (they should look
the same or better; the lime button on `06` can optionally soften to `brandFill`).

---

## 5. Implementation order (one branch: `fix/app-light-theme-system`)

1. **Build the token system** — `ReactiColors` extension (light+dark) + full light
   `ColorScheme` + dark `ColorScheme` (today's values) in `app/lib/theme/app_theme.dart`.
2. **Theme all shared components** (Section 3) on both `ThemeData`s.
3. **Verify Dark is pixel-identical** to today after the refactor (regression guard).
4. **Migrate hardcoded colours** to tokens, screen by screen, **starting with the broken
   ones**: Profile → Chat list → Inbox/composer → the blank screen. Then sweep the
   remaining `Colors.white`/`Colors.black`/dark `AppColors` usages app-wide.
5. **Avatars & placeholders** → `avatarPlaceholder` (so they don't vanish on white).
6. **Status bar** brightness per mode.

Could be two PRs if large: (5a) token system + component themes + Dark-identical proof;
(5b) the hardcoded-colour migration. Keep Dark perfect throughout.

---

## 6. Definition of done

1. **Every screen** renders legibly and cohesively in **Light**, including Profile, Chat
   list, Inbox, and the blank screen — matching the polish of Dark.
2. **Canvas is off-white with white cards** (not flat pure white); lists/rows/bubbles read
   as layered.
3. **All text meets WCAG AA** (≥4.5:1 normal) on its background; no pale-on-white, no
   white-on-white, no invisible app-bar titles.
4. **Brand is legible**: lime only as a fill with dark text; active tabs/links/wordmark/
   send icon use `brandAccent`. No lime text/icons on white.
5. **All surfaces themed**: cards, app bars, **bottom nav**, sheets, inputs, chips,
   switches, dividers, **chat bubbles**, **composer**, avatars.
6. **Colours come from tokens** (`ColorScheme` / `ReactiColors`), proven by grep: no
   `Colors.white`/`Colors.black`/dark-only `AppColors` driving visible colour.
7. **Dark mode unchanged** (pixel-identical spot-check on chat list + profile).
8. **Patent flow untouched behaviourally**; regression test green. RTL (Hebrew) intact.
   `flutter analyze` + `dart format .` clean.

---

## 7. Verification (before claiming done)

- Walk **every** screen in **both** modes and screenshot: onboarding, login/signup, OTP,
  Terms/Privacy, **chat list + all filter chips**, **1:1 inbox** (with text, incoming +
  outgoing bubbles, reaction, media/blur), **group inbox**, **composer**, media picker
  sheet, Friends, Contacts, Requests, Search, **Profile**, Edit Profile, Privacy &
  Security, Read Receipts, Usage Data, Change Password, Permissions List, and screen `05`.
- For each: every text/icon legible? every surface matches the mode? bubbles/composer/
  nav themed? Paste before/after **Light** screenshots (esp. Profile, Chat list, Inbox) in
  the PR.
- Add **golden/screenshot tests** in both modes for: chat list, a 1:1 inbox with bubbles,
  a settings screen, the composer — to catch future regressions.
- Quick **contrast check** (any WCAG tool) on: primary text on canvas, secondary text on
  card, `brandAccent` on white, `onBrandFill` on lime, bubble text on both bubbles.

---

## 8. Key files index

- `app/lib/theme/app_theme.dart` — token system, `ReactiColors` extension, both
  `ColorScheme`s + component themes (the hub).
- `app/lib/main.dart` — `GetMaterialApp` `theme` / `darkTheme` / `themeMode` wiring.
- `app/lib/gen/colors.gen.dart` + `assets/color/colors.xml` — `AppColors` (dark-biased;
  don't use where a colour must flip).
- Broken screens: Profile + Edit Profile widgets; `chat_screen.dart` (list, cards, filter
  chips); `inbox_screen.dart` / `group_inbox_screen.dart` (app-bar title, bubbles,
  composer); the blank screen (identify — likely Terms/Privacy or an empty state).
- Composer/bubbles: `send_message_widget.dart`, `sender_message_widget.dart`,
  `sender_text_bubble.dart`, `receiver_message_widget.dart` (**patent — colour tokens
  only, no behaviour change**).
- Bottom nav: `app/lib/features/navigation/presentation/navigation_screen.dart`.
- Supersedes: `docs/BUG-light-theme-incomplete-2026-07-01.md`. Extends Phase 1 of
  `docs/PLAN-theme-and-media-picker-2026-07-01.md`.

---

## 9. References (how the majors do light mode)

- iOS grouped backgrounds & semantic label/separator colours (the off-white-canvas +
  white-card model, and text token hexes): Apple `systemGroupedBackground` #F2F2F7 /
  `secondarySystemGroupedBackground` #FFFFFF; Sarunw "Dark color cheat sheet."
- WhatsApp light bubbles: incoming white, outgoing light green (#D9FDD3-family); soft
  off-white chat background.
- Material 3 colour roles (surface / surfaceContainer / outline) for the `ColorScheme`
  structure.

See the chat message accompanying this doc for the source links.
