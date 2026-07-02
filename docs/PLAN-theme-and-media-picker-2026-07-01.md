# PLAN — Dark/Light theme toggle + simplified media picker

**Date:** 2026-07-01
**Author:** Achia (decisions) + Claude (research, design, drafting)
**For:** Claude Code
**Status:** Approved for implementation, phase by phase. Do **not** start a phase
without confirming with Achia, per `CLAUDE.md`.

---

## 0. How to use this document

This plan covers the two items from Achia's 2026-07-01 feature list that need **no
further research** — they are well-scoped client-only changes:

1. **Dark / Light mode** — user-chooseable theme (System / Light / Dark), like WhatsApp.
2. **Simplified media picker** — collapse the 4-option sheet to **Camera / Gallery**,
   each handling both images and videos (like WhatsApp/Telegram).

The other five items on that list (onboarding redesign, OTP sender address, DNS/CDN
performance, recording-consent-at-signup, and the viral WhatsApp demo) each have
their own companion brief in `docs/` and are **not** in scope here.

Read these first, in order:

1. `CLAUDE.md` (repo root) — conventions, and the north-star reaction flow you must not break.
2. `docs/conventions.md` — commit format, Dart style, `dart format` / `flutter analyze` gates.
3. This file.

Branch naming: `feat/<scope>-<topic>` off `develop` (e.g. `feat/app-theme-mode`).
Conventional Commits. One phase per branch/PR. Each PR description states which phase
it implements and pastes the verification checklist with results.

Hard rules that apply to every phase:

- **Do not touch the patent flow** (silent front-camera reaction recording in
  `app/lib/features/chat/presentation/widget/receiver_message_widget.dart`). Phase 2
  edits the media *picker*, which feeds the send path — it must **not** change the
  blur/unblur, `mark-viewed`, recording trigger, reaction upload, or broadcast
  events. If a change drifts near any of those, extend the patent regression test.
- `dart format .` and `flutter analyze` must pass (app). No `dd()`/debug leftovers,
  no committed secrets, no TLS weakening.
- **RTL:** the app has Hebrew users. Any new UI (settings row, theme picker, media
  sheet) must lay out correctly in RTL.
- Both phases are **client-only** — no backend change, so no app-then-backend
  ordering concern. Still, don't regress the live App Store build's behaviour.

---

## Phase 1 — Dark / Light / System theme

### The goal (approved)

A user-chooseable appearance setting with three options, exactly like WhatsApp:

- **System default** (follow the OS) — the default for new and existing users.
- **Light**
- **Dark** (the app's current look)

The choice persists across launches and applies app-wide instantly on change.

### What exists today

- The app is **locked to a single dark theme**. `app/lib/main.dart` (≈L199–215)
  builds `GetMaterialApp` with one `ThemeData` (`useMaterial3: false`), no
  `darkTheme`, no `themeMode`. Key values:
  - `primaryColor: AppColors.allPrimaryColor` (lime `0xFFDCFC53`)
  - `appBarTheme.backgroundColor: AppColors.c000000` (black)
  - `scaffoldBackgroundColor: AppColors.scaffoldColor` (`0xFF010101`)
- Colours are **mostly centralised**: `app/lib/gen/colors.gen.dart` (FlutterGen,
  generated from `assets/color/colors.xml`), exposed as `AppColors.cXXXXXX`. ~221
  uses across 48 files — this is the good path.
- **But** there are **~78 hardcoded `Colors.white` / `Colors.black` (and variants)
  across 25 files** — e.g. `send_message_widget.dart` (`Colors.white30`,
  `Colors.white70`), `inbox_screen.dart` (`Icon(..., color: Colors.white)`). These
  will look wrong in light mode and are the bulk of the work.
- Persistence uses **GetStorage** (`appData`, initialised in `app/lib/helpers/di.dart`).
  Keys live in `app/lib/constants/app_constants.dart` (≈L27–64): `kKeyIsFirstTime`,
  `kKeyReadReceipts`, `kKeyAnalyticsOptOut`, etc. **There is no theme key yet.**
- State management is **provider** (`^6.1.5+1`) with **GetX** for routing. Follow the
  existing provider pattern for the theme controller (don't introduce a new paradigm).

### Design / approach (approved)

Introduce a **semantic theme layer** rather than scattering `AppColors.cXXXXXX`
straight into widgets. Concretely:

1. **Two `ThemeData` objects** in a new `app/lib/theme/app_theme.dart`:
   - `AppTheme.dark` — reproduce today's look exactly (lift the current `ThemeData`
     out of `main.dart` verbatim so there is zero visual change in dark mode).
   - `AppTheme.light` — the new one. Map each dark token to a sensible light
     equivalent: white/near-white surfaces, dark text, keep the lime
     `allPrimaryColor` as the brand accent (it reads on both). Define a proper
     `ColorScheme`, `appBarTheme`, `scaffoldBackgroundColor`, text colours, icon
     colours, divider/border colours.
2. **Prefer `Theme.of(context)` / `ColorScheme` tokens** (`surface`, `onSurface`,
   `primary`, `outline`, etc.) in migrated widgets, so a single widget renders
   correctly in both themes. `AppColors` constants remain valid for
   brand-fixed colours (e.g. the lime accent) but must **not** be used where the
   colour needs to flip between light and dark.
3. **`ThemeController`** (provider `ChangeNotifier`) holding a `ThemeMode`
   (`system` / `light` / `dark`), reading/writing a new
   `kKeyThemeMode` GetStorage key. Default when unset: `ThemeMode.system`.
4. **Wire into `GetMaterialApp`**: `theme: AppTheme.light`, `darkTheme: AppTheme.dark`,
   `themeMode: controller.themeMode`. Rebuild on change.
5. **Settings UI:** add an "Appearance" (or "Theme") row in the Profile/Settings area
   with a three-way selector (System / Light / Dark). Match the existing settings-row
   style used by the read-receipts / analytics toggles.

### Implementation steps

1. Create `app/lib/theme/app_theme.dart` with `AppTheme.dark` (verbatim copy of the
   current theme) and `AppTheme.light`. Remove the inline `ThemeData` from `main.dart`
   and reference these. **Verify dark mode is pixel-identical to today.**
2. Add `kKeyThemeMode` to `app_constants.dart`. Add `ThemeController`
   (provider) that loads/saves it and exposes `themeMode` + `setThemeMode(...)`.
   Register it with the existing provider tree; wire `themeMode` into `GetMaterialApp`.
3. Add the Appearance selector to the settings screen (three options + persistence +
   instant apply). RTL-correct.
4. **Migrate hardcoded colours.** Sweep the ~78 `Colors.white`/`Colors.black`/
   `Colors.whiteNN`/`Colors.blackNN` occurrences in the 25 files. For each, replace
   with the appropriate `Theme.of(context).colorScheme.*` token (or a new named token
   in `app_theme.dart`). Do this **screen by screen**, checking each in both modes.
   Prioritise the high-traffic surfaces: chat list, inbox, group inbox, message
   bubbles, composer/`send_message_widget`, profile/settings, auth/onboarding.
   - **Do not** alter colours inside `receiver_message_widget.dart`'s blur/reaction
     path in a way that changes the patent flow's behaviour; a visual token swap is
     fine, a logic change is not.
5. Handle **status-bar / system-chrome** brightness per theme (`SystemUiOverlayStyle`)
   so the iOS status bar icons are legible in both modes.

### Verify before merge

- Toggle System / Light / Dark in settings → whole app switches instantly and the
  choice survives an app restart.
- With System selected, flipping the iOS appearance flips the app.
- **Dark mode is visually identical to the current App Store build** (side-by-side a
  few key screens).
- Light mode: chat list, 1:1 inbox, group inbox, message bubbles, composer, profile,
  auth, and onboarding are all legible — no white-on-white or black-on-black, no
  invisible icons/borders. Blurred-media placeholders and the reaction UI look correct.
- RTL (Hebrew) layout verified on the settings selector and any touched screens.
- `flutter analyze` + `dart format .` clean. **Patent regression test green** (this
  phase shouldn't touch it, but confirm).

### Notes

- This is medium effort; the theme plumbing is quick, the **colour migration is the
  work**. It's safe to land in two PRs if the file sweep is large: (1a) theme
  infrastructure + settings toggle (light mode still rough), (1b) the colour
  migration. If split, say so in the PR and keep dark mode perfect throughout.

---

## Phase 2 — Simplify the media picker (Camera / Gallery)

### The problem

Sending media opens a bottom sheet with **four** options — Pick Image from Gallery,
Pick Image from Camera, Pick Video from Gallery, Pick Video from Camera. WhatsApp and
Telegram need only **Camera** and **Gallery**; each handles photos and videos.

### What exists today

- Sheet widget: `app/lib/features/chat/presentation/widget/media_picker_sheet.dart`
  (`MediaPickerSheet`, a `StatelessWidget`) — four `GestureDetector` rows calling
  `onPickGalleryImage`, `onPickCameraImage`, `onPickGalleryVideo`, `onPickCameraVideo`.
- Picker package: **`image_picker: ^1.2.0`** (`pubspec.yaml` L45). No `file_picker`.
- Invoked from two places with duplicated logic:
  - 1:1 — `app/lib/features/chat/presentation/inbox_screen.dart`
    (`_picker` L135–144; four `pick*` methods L190–240; `_imagePickerDialog()`
    L802–828). Picked media staged in `ValueNotifier<XFile?> selectedImage` +
    `selectedMediaType` ('image'|'video').
  - Group — `app/lib/features/chat/presentation/group_inbox_screen.dart`
    (same structure; `MediaPickerSheet` shown L915–930).
- After picking, `SendMessageWidget` watches those ValueNotifiers to preview/send.

### Design / approach (approved)

Two options in the sheet:

- **Gallery** → one call to `image_picker`'s **`pickMedia()`** (available in 1.x),
  which lets the user pick **either an image or a video** from the library in a single
  flow. Detect the type from the returned `XFile` (mime type / extension) and set
  `selectedMediaType` accordingly.
- **Camera** → `image_picker`'s camera source needs to know photo-vs-video **up
  front** (`pickImage(source: camera)` vs `pickVideo(source: camera)`); it cannot show
  a WhatsApp-style in-camera photo/video toggle. So, for now:
  - Tapping **Camera** presents a small inline choice (**Photo / Video**), then calls
    the matching picker. This keeps the top level at two items while preserving both
    capture modes.
  - A true unified custom camera (live photo/video toggle via the `camera` package) is
    a **deferred fast-follow**, not part of this phase — noted below.

Keep the existing staging contract unchanged: whatever is picked still lands in
`selectedImage` + `selectedMediaType`, so the send path and the reaction flow are
untouched.

### Implementation steps

1. Rework `MediaPickerSheet` to two rows: **Gallery** and **Camera** (keep the current
   dark styling / radius / spacing; make it theme-aware per Phase 1 if Phase 1 has
   landed). New callbacks e.g. `onPickFromGallery`, `onPickFromCamera`.
2. In `inbox_screen.dart`:
   - Add a `pickFromGallery()` using `pickMedia()`; infer image/video from the result
     and set `selectedImage` + `selectedMediaType`.
   - Add `pickFromCamera()` that shows the inline Photo/Video choice, then calls the
     existing `pickCameraImage()` / `pickCameraVideo()` logic (reuse it — don't
     duplicate).
   - Update `_imagePickerDialog()` to show the new two-option sheet.
3. Apply the **same** changes in `group_inbox_screen.dart`. **De-duplicate**: extract
   the shared picker logic into one place (a small mixin or helper) so 1:1 and group
   don't drift. If extraction is risky, at minimum keep the two implementations
   byte-identical and note the debt.
4. Confirm iOS Info.plist usage strings for camera, microphone (video), and photo
   library are all present (they must be, since all four modes exist today) — no
   change expected, just verify after refactor.
5. Remove now-dead code paths only if trivially safe; otherwise note in the PR.

### Verify before merge

- Media sheet shows exactly **two** options: Gallery and Camera.
- **Gallery** lets you pick an image *or* a video in one flow; the correct
  `selectedMediaType` is set and the preview/send works for both.
- **Camera** → Photo captures an image; Camera → Video captures a video; both send.
- Works identically in **1:1 and group** chats.
- The reaction/patent flow is unaffected: send media from A, open on B → blur → tap →
  silent record → reaction upload still works. **Patent regression test green.**
- RTL (Hebrew) layout of the sheet verified. `flutter analyze` + `dart format .` clean.

---

## Suggested execution order

1. **Phase 2 (media picker)** first — smaller, self-contained, no cross-cutting sweep.
   Good warm-up and independently shippable.
2. **Phase 1 (theme)** second — larger due to the colour migration; benefits from
   being able to theme the new media sheet as it's built.

If Phase 1 lands first, build the Phase 2 sheet theme-aware from the start.

One branch + PR per phase (Phase 1 may be two PRs). Confirm with Achia before starting
each phase, per `CLAUDE.md`.

---

## Deferred / future (captured so we don't lose it)

- **Unified custom camera** with a live photo↔video toggle (WhatsApp-style), using the
  `camera` package instead of `image_picker` for capture. Bigger lift (custom camera
  UI, permissions, recording controls). Revisit after Phase 2 if the inline
  Photo/Video choice feels clunky.
- **Multi-select gallery** (`pickMultipleMedia`) — send several items at once. Out of
  scope now.
- A fuller **design-token / theme extension** system (Material `ThemeExtension`) if the
  colour set grows; the two-`ThemeData` approach is enough for now.

---

## Open questions for Achia

- **Default theme for existing users:** `System` (recommended) or force-keep `Dark` so
  nothing changes for them unless they opt in? (Plan assumes `System`.)
- **Camera UX:** accept the inline Photo/Video choice for now, or wait and build the
  unified custom camera in one go? (Plan assumes inline choice now, custom camera
  deferred.)

---

## Key files index

- `app/lib/main.dart` — `GetMaterialApp` theme wiring (≈L199–215).
- `app/lib/gen/colors.gen.dart` + `assets/color/colors.xml` — `AppColors` source.
- `app/lib/constants/app_constants.dart` — GetStorage keys (add `kKeyThemeMode`).
- `app/lib/helpers/di.dart` — GetStorage (`appData`) init.
- **New:** `app/lib/theme/app_theme.dart` (dark+light), `ThemeController` (provider).
- `app/lib/features/chat/presentation/widget/media_picker_sheet.dart` — the sheet.
- `app/lib/features/chat/presentation/inbox_screen.dart` — pickers + invocation (1:1).
- `app/lib/features/chat/presentation/group_inbox_screen.dart` — pickers + invocation (group).
- `app/lib/features/chat/presentation/widget/send_message_widget.dart` — consumes the
  staged media; also a hotspot of hardcoded `Colors.*`.
- Hardcoded-colour hotspots for Phase 1: `send_message_widget.dart`, `inbox_screen.dart`
  (and 23 more — grep `Colors.white`, `Colors.black`, `Colors.white30/70`).
- **Do not modify behaviourally:** `receiver_message_widget.dart` (patent flow).
