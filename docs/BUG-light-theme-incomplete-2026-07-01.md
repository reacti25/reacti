# BUG — Light theme is incomplete (background only, not a full re-theme)

**Date:** 2026-07-01
**Reporter:** Achia (on-device, iOS) + Claude (diagnosis)
**For:** Claude Code
**Relates to:** `docs/PLAN-theme-and-media-picker-2026-07-01.md` — Phase 1. The theme
*plumbing* (System/Light/Dark toggle + a light `ThemeData`) landed, but the **colour
migration step was not completed**, so Light mode is broken. This doc is the fix spec.
**Screenshots:** `docs/screenshots/light-theme-issues-2026-07-01/` (see that README).

---

## 1. Summary of the problem

Choosing **Light** mode currently only flips the **scaffold background to white**. The
app's text, icons, cards, list rows, inputs, switches, segmented controls and the
bottom navigation are still coloured for a **dark** background — mostly white/pale text
and hardcoded dark component colours. The result on a white background:

- **Titles and body text are invisible or near-invisible** (pale/white text on white).
- **Whole screens are blank white** (all content is white-on-white).
- **Some components stayed dark** (cards, bottom nav) on an otherwise white page → a
  patchwork, inconsistent look.
- **The lime brand accent** is used as-is and clashes / looks harsh on white.

**The requirement:** choosing Light must switch the **entire** theme — every surface,
text style, icon, card, control, and the nav bar — to a cohesive light palette, the way
Dark mode is cohesive today. Not just the background. This is exactly Phase 1 step 4
("Migrate hardcoded colours") in the plan, which appears to have been skipped or only
partially done.

---

## 2. Root cause (what to actually fix)

Two things, both already called out in the Phase 1 plan:

1. **~78 hardcoded `Colors.white` / `Colors.black` (and `AppColors.cXXXXXX` chosen for a
   dark bg) across ~25 files** were never migrated to theme-aware tokens. These are the
   invisible-text and mismatched-component bugs.
2. **Widgets read fixed colours instead of `Theme.of(context)` / `ColorScheme`.** Every
   text/icon/surface colour that must differ between modes has to come from the theme,
   not a constant that assumes dark.

Fix = do the migration properly: define a real light `ColorScheme` + component themes,
and drive **every** widget's colours off the theme. Nothing user-visible may remain
pinned to a dark-mode colour.

---

## 3. Per-screen defects (from the screenshots)

**`01-usage-data.png` — Usage Data (light):** The "Usage Data" screen **title is
ghosted** (pale on white, nearly unreadable). The explanatory paragraph is **light grey
on white — fails contrast**. The switch renders a **muddy olive** instead of a clean
light-mode accent. → Title, body text, and switch colours must all be theme-driven.

**`02-read-receipts.png` — Read Receipts (light):** Same as above — **title ghosted**,
**body text too low-contrast**, **muddy toggle**.

**`03-change-password.png` — Change Password (light):** **Title invisible.** Input
fields are OK-ish (grey field, grey placeholder), but the **eye/visibility icons are
bright lime** and the **primary button is loud lime** — both clash on white and need a
light-mode-appropriate accent + proper contrast. Confirm placeholder vs. entered-text
contrast too.

**`04-permissions-list.png` — Permissions List (light):** The page title is fine
(black), **but each row's permission NAME is invisible** (white-on-white) — only the red
"Denied" status shows. Every row label is missing because its text colour didn't flip.

**`05-blank-screen.png` — (light):** An **entirely blank white screen** with only the
back chevron — all content is white-on-white and lost. Identify which screen this is
(likely a text/info screen such as Terms/Privacy or an empty-state) and give it real
light-mode text colours.

**`06-friend-requests.png` — Requests (light):** The page is white, the "Friend
requests" lime pill shows, **but the request card is still dark** (hardcoded dark
surface with white text) and the **bottom nav bar stayed dark**. Dark components on a
white page = inconsistent. Cards and the nav bar must adopt light surfaces in light mode.
Also note there's **no themed status-bar/safe-area treatment** at the top.

**`07-friends-tab.png` / `08-contacts-tab.png` — Friends/Contacts (light):** White
background, **dark friend card**, **dark segmented Friends/Contacts control**, and
**dark bottom nav** — same patchwork. The lime search field/placeholder/icon also need a
light-mode treatment (lime-on-white is harsh). Segmented control, card, and nav must all
re-theme.

**`09-chat-list-dark-REFERENCE.png` and `10-profile-dark-REFERENCE.png` — Dark
(CORRECT):** These show Dark mode working and cohesive. **Do not change Dark.** Use these
as the cohesion bar: Light mode should feel this finished and consistent, just light.

---

## 4. Definition of done (light mode)

Every one of these must hold in **Light** mode, with **Dark mode unchanged**:

1. **All text is legible** — titles, section headers, body copy, list-row labels,
   placeholders, timestamps, empty-state text. Target **WCAG AA** contrast (≥ 4.5:1 for
   normal text) against its actual background. No pale-on-white, no white-on-white.
2. **No blank/lost screens.** Every screen that renders content in Dark renders the same
   content, legibly, in Light.
3. **All surfaces re-theme:** scaffold, app bars, **cards/containers**, list rows,
   **bottom navigation bar**, sheets/dialogs, inputs, chips, segmented controls,
   dividers/borders. No component stays a dark colour on a light page.
4. **Controls re-theme:** switches/toggles, buttons, icons — clean light-mode colours,
   correct on/off states, correct text-on-accent contrast.
5. **Brand accent (lime) is tuned for light:** use it as an accent, ensure text/icons on
   lime are dark and readable, and avoid lime text/icons directly on near-white where it
   fails contrast. Keep it recognisably Reacti.
6. **Status bar / system chrome** uses the right brightness per mode (dark icons in
   Light, light icons in Dark) via `SystemUiOverlayStyle`.
7. **Cohesion:** Light mode looks as finished as the two dark REFERENCE screenshots — not
   a patchwork.
8. **Mechanism:** colours come from `Theme.of(context)` / `ColorScheme` / component
   themes, **not** hardcoded `Colors.*` or dark-only `AppColors` constants. Grep proves
   the migration: no remaining `Colors.white`/`Colors.black`/`Colors.whiteNN` driving
   user-visible colour in the migrated screens.
9. **Patent flow untouched** behaviourally (`receiver_message_widget.dart`) — a colour
   token swap is fine, a logic change is not. Patent regression test stays green.
10. **RTL (Hebrew)** unaffected. `flutter analyze` + `dart format .` clean.

---

## 5. How to verify (do this before claiming it's fixed)

Walk **every** screen in **both** Light and Dark and screenshot each, then eyeball:

- Onboarding, Login/Signup, OTP verify, Terms/Privacy.
- Chat list (+ All/1:1/Groups/Unseen chips), 1:1 inbox, group inbox, message bubbles
  (sent + received + reaction), media/blur placeholders, the media picker sheet.
- Friends tab, Contacts tab, Requests, Search.
- Profile, Edit Profile, Privacy & Security, **Read Receipts**, **Usage Data**,
  **Change Password**, **Permissions List**, and the screen shown blank in
  `05-blank-screen.png`.

For each: is every text/icon legible, does every surface match the mode, do toggles/
buttons look right? A quick automated aid: add **golden/screenshot tests** for a few key
screens (chat list, a settings screen, a bubble) in both modes so regressions are caught.

**Do not** consider this done until the settings screens in the screenshots
(`01`–`04`), the blank screen (`05`), and the mixed screens (`06`–`08`) are all fully
legible and cohesive in Light.

---

## 6. Suggested approach for Claude Code

1. Re-read Phase 1 of `docs/PLAN-theme-and-media-picker-2026-07-01.md`.
2. Flesh out the **light `ColorScheme` + component themes** in `app/lib/theme/app_theme.dart`
   (app bar, card, bottom-nav-bar, input decoration, switch, chip, dialog, text themes)
   so most widgets get correct colours **for free** from the theme.
3. Then sweep the **hardcoded-colour hotspots** and settings/list screens shown above,
   replacing fixed colours with `colorScheme.*` / `textTheme.*` tokens. Prioritise the
   screens in the screenshots first (they're the proof set).
4. Keep verifying Dark is pixel-identical to today throughout.
5. This can be its own PR/branch, e.g. `fix/app-light-theme-migration`, on top of the
   Phase 1 work. Paste before/after screenshots (Light) in the PR.

---

## 7. Key files index

- `app/lib/theme/app_theme.dart` — light/dark `ThemeData` + component themes (the fix hub).
- `app/lib/main.dart` — `GetMaterialApp` theme wiring.
- `app/lib/gen/colors.gen.dart` + `assets/color/colors.xml` — `AppColors` (dark-biased; do
  not use where a colour must flip).
- Settings/list screens in the screenshots: the Usage Data, Read Receipts, Change
  Password, Permissions List, Friends/Contacts, Requests, and Profile widgets.
- Bottom navigation: `app/lib/features/navigation/presentation/navigation_screen.dart`.
- Hardcoded-colour hotspots: `send_message_widget.dart`, `inbox_screen.dart`, and ~23
  more (grep `Colors.white`, `Colors.black`, `Colors.white30/70`).
- **Do not modify behaviourally:** `receiver_message_widget.dart` (patent flow).
