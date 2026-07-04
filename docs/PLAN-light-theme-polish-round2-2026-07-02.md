# PLAN — Light-theme polish, round 2 (+ first-run appearance popup)

**Date:** 2026-07-02
**Author:** Achia (via Cowork investigation)
**Branch to work on:** continue on `fix/app-light-theme-polish` (or a fresh
`fix/app-light-theme-polish-2` off it) — Achia's call.
**Driver:** Claude Code executes this. Read this whole doc first, then confirm
scope with Achia before starting Task 5 (it touches the signup flow).

> **Golden rule from `CLAUDE.md`:** dark mode is frozen and must stay
> pixel-identical. Every change here is *light-mode-only* — always branch on
> `Theme.of(context).brightness == Brightness.light` (or read `context.reacti`
> tokens, which already differ per mode) and leave the dark path untouched.
> Do not touch the patent flow (silent recording / `mark-viewed` / reaction
> upload). Run `dart format .` + `flutter analyze` and keep them green.

---

## Task 0 — The "1:1 chats disappeared" report: NOT a code bug. Do not "fix" it.

**Verdict:** this is the **staging-only 24h auto-prune working as designed**, not
a regression from the theme work. Confirmed by Achia: the affected build points
at **staging**.

Why the symptom ("old 1:1 chats gone, but I can start new ones") matches exactly:

- `ChatService::listCombined()`
  (`backend/app/Services/ChatService.php`, ~line 618) builds the 1:1 list purely
  from **surviving `Chat` message rows** — it selects users the auth user has
  `senders`/`receivers` rows with. It does **not** gate on contacts/friends.
- `backend/app/Console/Commands/PruneStaleStagingChat.php` **hard-deletes**
  (`forceDelete`) chat/group/reaction messages + media older than
  `config('staging.prune_hours')` (default 24h). Once every message between
  two users is pruned, that user drops out of `listCombined` → the 1:1 "vanishes."
  Fresh chats have rows younger than 24h, so they still appear.
- The command is **double-gated** to staging (`staging.prune_enabled` **and** a
  positive host allowlist `staging.prune_host`); production (`reacti.io`) fails
  the host gate and **never prunes**. So this cannot happen to real users.

**Action:**
1. **No production code change.** Verify the front-end filter logic is intact
   (it is — `applyChatFilter` in
   `app/lib/features/chat/logic/chat_list_logic.dart` was not changed on the
   theme branch; `all` returns everything).
2. **Optional QoL for testing only:** if losing test chats every 24h is
   annoying, bump `staging.prune_hours` (e.g. to `168` = 7 days) in the
   **staging `.env` only** (`STAGING_PRUNE_HOURS`). This is a config change on
   the staging server, not a repo code change, and must never be set on prod.
3. Tell Achia in the PR/notes that this was diagnosed as expected staging
   behaviour so it isn't mistaken for a real regression later.

---

## Task 1 — Login/auth logo wordmark: bright-on-bright contrast

**Symptom:** on the login screen the "Reacti" wordmark under the logo badge is
lime (`#DCFC53`) on the off-white canvas (`#EAE8E3`) → nearly invisible in light.

**Root cause:** `assets/icons/app_logo.svg` is a **vertical lockup** (viewBox
`168×164`): the lime badge **and** the lime "Reacti" wordmark are baked into one
SVG. `login_screen.dart` just renders it (`SvgPicture.asset(Assets.icons.appLogo,
height: 120.h)`, ~line 79). There is no separate `Text('Reacti')` to recolor —
the wordmark is vector paths inside the SVG. The lime badge itself is fine (solid
shape, high internal contrast); only the thin wordmark lettering fails on white.

**Fix — recommended (clean, fully theme-controllable):**
1. Create a **mark-only** asset `assets/icons/app_logo_mark.svg` = the badge with
   its black glyph, wordmark paths removed. (Claude Code can render `app_logo.svg`
   to confirm which of the 15 paths are the badge vs the 6-letter wordmark, then
   strip the wordmark paths. The 4 `fill="black"` paths are the smiley features;
   keep those. Keep the badge's lime paths.) Register it in `pubspec.yaml`/regen
   `assets.gen.dart` as usual.
2. In the auth header (login, signup, forgot, verify — anywhere the lockup
   appears) render the mark + a themed `Text`:
   ```dart
   SvgPicture.asset(Assets.icons.appLogoMark, height: 96.h),
   UIHelper.verticalSpace(8.h),
   Text(
     'Reacti',
     style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
       fontSize: 26.sp,
       fontWeight: FontWeight.w700,
       color: context.reacti.brandAccent, // #4F5E00 light (legible), lime in dark
     ),
   ),
   ```
   `brandAccent` is already `#4F5E00` in light and `#DCFC53` in dark, so this is
   legible in light and identical to today in dark.

**Fix — fallback if splitting the SVG is not worth it:** ship a light-variant
lockup `app_logo_light.svg` (wordmark paths recolored to `#4F5E00`, badge stays
lime) and pick per brightness:
```dart
SvgPicture.asset(
  Theme.of(context).brightness == Brightness.light
      ? Assets.icons.appLogoLight
      : Assets.icons.appLogo,
  height: 120.h,
),
```

**Do NOT** apply a single `colorFilter` to the whole lockup — it would flatten
the badge's lime identity and the black glyph.

**Test:** widget test that pumps the login screen under `AppTheme.light` and
asserts a `Text('Reacti')` (or the light asset) is present with `brandAccent`;
and under `AppTheme.dark` the appearance is unchanged.

---

## Task 2 — Bottom nav: active tab is indistinguishable

**Symptom:** you can't tell which tab is selected on a real device.

**Root cause:** in `navigation_screen.dart` `_buildNavItem` the only difference
between active/inactive is the tint: active = `brandAccent` (`#4F5E00` dark
olive-lime), inactive = `textSecondary` (`#5F5D57` mid-grey). In light those two
are almost the same luminance → no perceivable difference.

**Fix (recommended): give the active tab a filled lime pill.** Unambiguous, on
brand, matches the selected filter chips on the chat list.

Replace the per-item `Column` with a pill-backed layout for the selected item:
```dart
final bool isSelected = selectedIndex == index;
final reacti = context.reacti;

final Color fg = isSelected ? reacti.onBrandFill : reacti.textSecondary;

return Expanded(
  child: InkWell(
    // ...unchanged InkWell config...
    onTap: () => onItemTapped(index),
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: isSelected ? reacti.brandFill : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4.h,
          children: [
            SvgPicture.asset(
              icon,
              key: ValueKey('$icon$isSelected'),
              semanticsLabel: label,
              colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
            ),
            Text(
              label,
              style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                color: fg,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
```
This uses `brandFill` (lime block) + `onBrandFill` (near-black) for the active
pill in **both** modes — in dark it reads the same as the lime selection colour
already used elsewhere, so dark stays consistent. If Achia prefers a lighter
touch, the alternative is a 3px `brandAccent` top-indicator bar over the active
item + `brandAccent` bold label; but the pill is the clearest on-device.

**Test:** widget test pumping `NavigationScreen`, tap each tab, assert the active
item's container decoration colour == `brandFill` and inactive == transparent.

---

## Task 3 — Reaction bubble still looks "dark theme"

**State of play:** the outer reaction frame **was** migrated on the theme branch
(HEAD commit `6eadefb`) — `_buildReactionBubble()` now uses
`context.reacti.bubbleIn` (white in light) + hairline + `cardShadow`, the
"Reaction" label + icon use `brandAccent`, the video border uses `hairline` in
light, and the timestamp uses `onBubbleIn`. **First: confirm Achia's screenshot
was from a build that predates `6eadefb`** — if their installed build is older,
much of this is already fixed and they just need the latest build.

**Remaining light-mode polish** (in
`app/lib/features/chat/presentation/widget/receiver_message_widget.dart`):
1. **`_buildBlurPlaceholder()`** (the pre-view blur state) — audit it the same
   way `_buildVideoMedia()` was: any hardcoded `Colors.white**`, `0xFF1A1E0A`,
   `Colors.black`, or `AppColors.*` inside the placeholder/overlay must become
   `context.reacti.*`. The blur/unblur transition is patent-flow-adjacent, so
   change **colours only**, keep the timing/trigger identical, and cover it with
   a regression test (see below).
2. **Play/controls overlay** — if the play button or scrubber draws on a dark
   scrim, in light give it a lighter scrim so it fits the white frame. Colour
   only; do not touch `custom_video_controls.dart` logic.
3. **"Reaction" label** — optionally wrap it in a small `brandFill`-tinted chip
   (`brandFill` @ ~15% + `brandAccent` text) so it reads as a badge rather than
   floating lime text. Cosmetic, light-only.
4. Grep the whole file for `Color(0xFF1A1E0A)`, `Colors.white54/30/70`,
   `AppColors.` and confirm none remain on a light-visible surface.

The video *content* itself will always be whatever the camera captured (often
dim) — that's expected; the goal is that the **frame, label, controls and
timestamp** read as light-theme, not the footage.

**Test:** extend/keep the existing reaction regression test so the full loop
(mark-viewed → silent record → reaction upload → render) still passes, and add a
light-mode golden/pump asserting the reaction frame background == `bubbleIn`
(white) and border == `hairline`.

---

## Task 4 — Overall "bright" appearance polish (nice-to-haves)

Light-only, low-risk. Pick up as time allows:
- **Consistent card elevation:** chat rows already got `cardShadow`; make sure
  Friends, Request and Profile list rows/cards use the same `card` + `cardShadow`
  so the whole app has one soft-elevation language (grep for remaining
  `AppColors.c18181B` / `c252529` used as backgrounds on light-visible widgets).
- **Canvas vs card separation:** the warm ramp (`canvas #EAE8E3` / `card #FFF` /
  `surfaceVariant #F1EFEA`) is good; just verify no screen still paints a pure
  `#FFFFFF` scaffold that makes white cards disappear.
- **Status bar / overlay:** confirm `SystemUiOverlayStyle.dark` icons in light
  are applied everywhere (already in `appBarTheme.systemOverlayStyle`).
- **Toasts** were migrated on the branch — spot-check they're legible on light.

No new tokens needed — everything is already in `ReactiColors.light`.

---

## Task 5 — First-run appearance popup, *after permissions*, with Skip

**What Achia wants:** on first **sign-up**, after the permission prompts, pop a
dialog asking Light vs Dark, with a **Skip**. Skip → **follow system** (which is
the default and resolves to Light).

**What exists today:**
- `ThemeController` (`app/lib/theme/theme_controller.dart`) already persists
  `ThemeMode` under `kKeyThemeMode`, **defaults to `ThemeMode.system`**. Good —
  "Skip" just means "leave it at system / don't write a preference."
- `AppearanceOptions` (`app/lib/theme/appearance_options.dart`) is a reusable
  System/Light/Dark selector that applies live.
- There's already a full-screen `AppearanceOnboardingScreen` shown **before
  login** at the end of the carousel (`on_board_screen.dart` → route
  `appearanceOnboardingRoute`). That's the wrong moment per Achia (wants it
  post-permissions on signup), so we move the moment.

**Flow reality to respect:** signup completes at
`signup_verify_otp_screen.dart` (~line 107) which
`navigateToReplacementUntil(Routes.navigationScreen)`. Permissions are requested
contextually (`permission_list_screen.dart` calls
`permissionItem.permission.request()`); there is no dedicated first-run
permission screen wedged into signup. So "after permissions" = after the signup
verification + permission grants, right as the user first lands in the app.

**Recommended wiring:**
1. Add a one-time flag `kKeyAppearanceAsked` (bool, default false) in
   `app_constants.dart`.
2. Build a `showAppearancePickerDialog(BuildContext)` (new file
   `app/lib/theme/appearance_picker_dialog.dart`) — a `showDialog` (barrier
   dismissible = false) that reuses `AppearanceOptions` and has two actions:
   - **"Use this"/Continue:** persists the tapped choice via `ThemeController`
     and pops.
   - **"Skip":** pops without writing a preference (stays `system`).
   Both set `appData.write(kKeyAppearanceAsked, true)`. Style it as a themed
   `AlertDialog` (the `dialogTheme` in `AppTheme` already gives it `card` bg +
   shadow).
3. Trigger it once, after the first-run permission step, before the user starts
   using chat. Cleanest hook: in `NavigationScreen.initState` /
   `WidgetsBinding.instance.addPostFrameCallback`, `if (isFreshSignup &&
   !appData.read(kKeyAppearanceAsked)) showAppearancePickerDialog(context);`.
   Determine `isFreshSignup` from a flag set on the signup-verify success path
   (so returning logins never see it). If the app already runs its
   permission prompts on first entry to `NavigationScreen`, await those first,
   then show the dialog.
4. **Retire the pre-login step:** change `on_board_screen.dart` so the carousel's
   last page routes straight to `Routes.loginScreen` instead of
   `appearanceOnboardingRoute`. Keep `AppearanceOnboardingScreen` + its route in
   the tree only if you want a fallback, otherwise delete both and the
   `kKeyIsFirstTime`-based routing that fed it. Confirm with Achia before
   deleting.
5. The Settings → Appearance screen (`appearance_settings_screen.dart`) stays as
   the permanent place to change it later — unchanged.

**Tests:**
- `theme_controller_test`: Skip leaves mode at `system`; choosing Light/Dark
  persists and reloads.
- widget test: dialog shows when `kKeyAppearanceAsked` is false + fresh signup,
  does **not** show on a normal login or once the flag is set.

---

## Sequencing, conventions, and definition of done

Suggested order (smallest-risk first): **2 → 1 → 4 → 3 → 5**. Task 0 is
verify-only.

- One Conventional-Commit per task, e.g.
  `fix(app): unambiguous active tab pill in bottom nav (light)`,
  `fix(app): legible Reacti wordmark on light auth screens`,
  `feat(app): first-run appearance picker after permissions`.
- `dart format .` and `flutter analyze` clean; add/keep the tests above.
- **Regression test the patent loop** if Task 3 touches the blur placeholder —
  full mark-viewed → silent record → reaction upload → render, per `CLAUDE.md`.
- Verify **dark mode is byte-for-byte unchanged** (pump each touched screen under
  `AppTheme.dark` and compare to before).
- On-device (or simulator) light-mode pass of: login, bottom bar on all four
  tabs, a reaction message, and a fresh signup showing the appearance dialog.
- Because the affected env is staging, expect old test chats to keep pruning at
  24h (Task 0) — that is not a bug in this work.
```
