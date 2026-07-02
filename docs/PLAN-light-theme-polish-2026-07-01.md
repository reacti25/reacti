# PLAN — Light theme polish: auth, media placeholder, nav, reaction frame

**Date:** 2026-07-01
**Author:** Achia (QA on device) + Claude
**For:** Claude Code
**Status:** Approved fix batch. Small, targeted follow-up to
`docs/PLAN-light-theme-refinement-2026-07-01.md` (depth pass — which worked). Confirm with
Achia before starting, per `CLAUDE.md`.
**Screenshots:** `docs/screenshots/light-theme-v4-2026-07-01/`.

---

## 0. Where we are

The light theme now has proper depth and is cohesive on most screens. Four issues remain,
all the **same root cause we've fixed elsewhere but which these surfaces bypassed**:
lime-on-light or white-on-light text/controls that disappear, plus one screen still using
dark-mode colours. All fixes use the **existing tokens** from the previous plans — no new
system, just apply them here.

Reminder of the two brand rules (from the color-system plan):

- **`brandAccent` #4F5E00** (darkened lime) = brand **text/icons on light** surfaces
  (links, active tab, wordmark, send icon, labels). Lime fails contrast on light.
- **`brandFill` #DCFC53** (lime) = **filled blocks only** (buttons, selected pills), always
  with dark text on top.

---

## 1. Problems & fixes

### 1.1 Login & Signup screens — fields and labels invisible (`01`)

Symptoms: "Email" / "Password" field labels and the "Login" heading are white; "Login to
continue" subtitle is pale; the input fields are pale-on-pale (no clear edge); "Forgot
Password", "Sign up", and the "Reacti" wordmark are lime on the pale canvas (low contrast).

Fixes:

- Field labels ("Email", "Password") → **`textPrimary`**.
- "Login" heading → **`textPrimary`**; "Login to continue" subtitle → **`textSecondary`**.
- Input fields → **`sunken` fill (#F1EFEA) + `hairline` border**, placeholder
  **`textTertiary`**, entered text **`textPrimary`**. They must read as clearly-bounded
  fields on the canvas (this is the InputDecorationTheme; if these screens use a custom
  field widget, point it at the theme).
- "Forgot Password", "Sign up" link, and the "Reacti" wordmark → **`brandAccent`**
  (not lime). "Don't have an account?" text → `textSecondary`.
- "Sign In" button stays `brandFill` + dark text (already correct).
- **Apply the identical fixes to the Signup screen** (same widgets/pattern) and to the OTP
  and Forgot-Password screens — they share this auth styling.

### 1.2 Media placeholder caption invisible (`03`)

Symptoms: the pre-load / sealed media placeholder (lime Reacti-logo tile with "Reacti" +
"Click to view the media") has a **white caption on pale** (invisible) and a faint tile.

Fixes:

- "Click to view the media" caption → **`textSecondary`** (legible).
- The placeholder tile → a visible **`card` surface + `hairline` border** (and the soft
  card shadow) so it reads as a tappable media block on the canvas. Keep the lime logo.
- The "Reacti" label on the tile → `brandAccent` (or `textPrimary`), not pale lime.
- This placeholder sits in the chat/blur path — **colour/surface only; do not change the
  blur/mark-viewed/reveal behaviour.**

### 1.3 Bottom-nav active item low contrast (`02`)

Symptoms: the selected tab (e.g. Chat) is **lime on the near-white nav** → barely visible.

Fix: selected nav icon + label → **`brandAccent` #4F5E00**; unselected → `textSecondary`;
nav background `card` with the soft separation from the refinement plan. (Set this in the
BottomNavigationBar/NavigationBar theme so it's global. This is the one place lime was used
as an on-light accent — switch it to `brandAccent`, consistent with the wordmark/links.)

### 1.4 Reaction frame still dark-mode (`04`)

Symptoms: the Reaction message (the card/frame around the recorded reaction video, with the
"Reaction" label and progress/fullscreen controls) is still **dark/olive** on the light
theme.

Fixes (colour tokens only):

- Reaction frame/card background → **`card`** (or `bubbleOut` tint if it's the sender's
  own reaction), with **`hairline`** border and the soft card shadow.
- "Reaction" label + camera icon → **`brandAccent`**.
- Control glyphs (play, fullscreen, scrubber, timestamp) → ensure contrast **against the
  video** (these overlay the video, so a semi-opaque dark scrim behind them is fine and
  should stay regardless of theme — the *frame* re-themes, the *video overlay controls*
  keep their legibility scrim).
- **This is the patent reaction UI.** Change **colour tokens only** — no change to
  recording, blur, mark-viewed, upload, or playback behaviour. Keep the patent regression
  test green.

---

## 2. The principle (apply everywhere, not just these four)

**Nothing may be bright-on-bright in light mode.** While in here, audit the whole app for
the same class of bug and fix any instance to the tokens:

- **No lime text/icons on a light surface** → use `brandAccent`. (Lime is fills only.)
- **No white/near-white text on the canvas or a card** → `textPrimary` (titles/labels) or
  `textSecondary` (subtitles, captions, empty states, timestamps).
- **Every input/placeholder/well** has a visible recessed fill (`sunken`) + `hairline` so
  it's clearly a field.
- **Every selected/active state** (tabs, chips, toggles) meets **WCAG AA** against its
  background.
- Check the surfaces easy to miss: **auth** (login, signup, OTP, forgot password),
  **media states** (loading, sealed, "click to view", captions), **reaction frames**,
  **empty states**, **toasts/snackbars**, **dialogs/bottom sheets**, **tooltips/badges**.

If a colour must differ between light and dark, it comes from a **token**, never a
hardcoded `Colors.white` / `AppColors` dark constant.

---

## 3. Implementation (branch: `fix/app-light-theme-polish`)

1. Auth screens (§1.1) — labels/headings/subtitles/links to tokens; fields via
   InputDecorationTheme (or the custom field widget) with `sunken` + `hairline`.
2. Media placeholder (§1.2) — caption + tile surface to tokens.
3. Bottom-nav theme (§1.3) — active = `brandAccent`.
4. Reaction frame (§1.4) — frame/label to tokens, keep video-overlay legibility scrim,
   **no behaviour change**.
5. App-wide audit sweep (§2) for remaining lime-on-light / white-on-light.
6. Dark mode pixel-identical; `flutter analyze` + `dart format .` clean.

---

## 4. Definition of done

1. Login/Signup/OTP/Forgot: all labels, headings, subtitles legible; input fields clearly
   bounded; brand links use `brandAccent`.
2. Media placeholder caption + tile clearly visible.
3. Bottom-nav active item clearly visible (dark-brand, not lime).
4. Reaction frame matches the light theme; video playback/controls still legible; behaviour
   unchanged; patent regression test green.
5. App-wide: no bright-on-bright anywhere — verified across auth, media, reactions, empty
   states, dialogs, toasts. All text ≥ WCAG AA.
6. Dark mode unchanged. RTL intact.

---

## 5. Verification

- Walk in Light: login → signup → OTP → forgot-password (every field/label/link visible);
  a chat with an unopened media placeholder (caption visible); a chat with a reaction
  (frame re-themed, video controls legible); tab through the bottom nav (each active state
  visible). Screenshot each.
- Contrast-check: field labels & entered text on `sunken`; placeholder caption on canvas;
  nav active `brandAccent` on `card`; "Reaction" label on the frame. All ≥ 4.5:1.
- Patent regression + backwards-compat tests green. Dark spot-check unchanged. Update
  golden tests (add an auth screen + a reaction bubble in light).
- Paste before/after Light screenshots for: login, the media placeholder, the reaction
  message, and the bottom nav.

---

## 6. Key files index

- `app/lib/theme/app_theme.dart` — tokens + InputDecorationTheme + BottomNavigationBar
  theme (nav active colour).
- Auth: `app/lib/features/auth/presentation/login/...`,
  `.../signup/...`, `.../signup_verify_otp/...`, `.../verify_otp/...` (labels, fields,
  links) — and the shared auth text-field widget if there is one.
- Media placeholder: the blurred/sealed media widget in
  `app/lib/features/chat/presentation/widget/` ("Click to view the media" tile).
- Reaction frame: `app/lib/features/chat/presentation/widget/receiver_message_widget.dart`
  (and the reaction bubble widget) — **patent UI, colour tokens only**.
- Bottom nav: `app/lib/features/navigation/presentation/navigation_screen.dart`.
- Builds on `docs/PLAN-light-theme-refinement-2026-07-01.md` and
  `docs/PLAN-light-theme-color-system-2026-07-01.md`.
