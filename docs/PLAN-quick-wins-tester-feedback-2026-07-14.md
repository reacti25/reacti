# PLAN — Tester-Feedback Quick Wins (2026-07-14)

_For Claude Code. Verified against `develop` (working checkout was `feature/message-menu-details-delete`; all line references below were read from `develop` via `git show develop:<path>`)._

## Scope

Eight small, independent items from the tester-feedback triage (`docs/FEEDBACK-triage-2026-07-14.md` §3). Each is one concern → one branch → one PR. None of them touch the patented silent-recording loop; **item 8 (haptics/sounds) has an explicit guardrail to keep it away from that flow — read it before starting.**

| # | Item | Branch | Effort |
|---|------|--------|--------|
| QW1 | Disable friend-request button once a request is pending | `feat/friends-request-button-guard` | S |
| QW2 | Search by username only (no more "everyone" list) | `feat/search-username-only` | S |
| QW3 | Return to the intro/explainer from the login screen | `feat/auth-return-to-intro` | S |
| QW4 | Tap profile photo to enlarge | `feat/profile-avatar-fullscreen` | S |
| QW5 | Privacy reassurance on the contacts prompt | `feat/contacts-privacy-note` | S |
| QW6 | Camera flash / torch toggle | `feat/camera-flash-toggle` | S |
| QW7 | Discarding a photo re-opens the camera | `feat/camera-discard-reopen` | S |
| QW8 | Haptics (+ light sounds) for send / receive | `feat/feedback-haptics` | S–M |

Suggested order: QW4, QW5, QW3 (pure UI, lowest risk) → QW1, QW6, QW7 (small behavior) → QW2 (client + backend) → QW8 (broadest). Ship each PR independently; do not stack.

## Conventions (apply to every PR)

- Branch off `develop`; **one concern per PR** (`docs/conventions.md`).
- Conventional Commits: `feat(scope): …`, `fix(scope): …`. Body explains *why*.
- Dart: `dart format .` and `flutter analyze` must pass; `StatefulWidget` config fields are `final`; files `lower_snake_case.dart`.
- PHP (QW2 only): `./vendor/bin/pint`; `camelCase` methods; one envelope `{success, message, data, code}`; real HTTP status codes.
- **No l10n system exists — all copy is hardcoded string literals** styled via `TextFontStyle.*`. Add new strings the same way.
- Theme: prefer `context.reacti.<token>` (the `ReactiColors` extension in `app/lib/theme/app_theme.dart`) for any new color. Note: the onboarding / login / find / search screens are still on the legacy flat `AppColors` palette (`app/lib/gen/colors.gen.dart`) and are dark-only — **match the surrounding screen's existing style** rather than mixing systems within one widget.
- GetStorage key constants live in `app/lib/constants/app_constants.dart`; the instance is `appData` (from `app/lib/helpers/di.dart`).
- Each PR must pass the required CI checks (`Analyze & Test` for app, `PHP Tests` for backend) and include/adjust tests where noted. Add a screenshot/screen-recording to each app PR description for on-device sign-off.

---

## QW1 — Disable friend-request button while a request is pending

**Feedback:** Tamar — "after sending a friend request the button should be grey/unavailable so you can't send several requests to the same person."

**Current state (`app/lib/features/search/presentation/search_screen.dart`):** the row action already has three states driven by response flags `data?.isFriend` and `data?.isRequestSent`: **Send Request** (L165-189), **Message** (L191-211, when `isFriend`), **Cancel** (L213-232, when `isRequestSent`). After a successful send it re-fetches and the button flips to Cancel. So the steady-state is mostly handled — the real gap is the **in-flight window**: between tapping "Send Request" and the re-fetch completing, the button stays enabled and tappable, allowing double-sends.

**Change:**

1. Add a per-row in-flight guard so the button disables immediately on tap. Track the set of user-ids currently being requested in local state:
   ```dart
   final Set<int> _sendingRequestIds = {};
   ```
2. In the Send Request `onTap` (L166-188), guard and disable:
   ```dart
   onTap: _sendingRequestIds.contains(data!.id)
       ? null // CustomButton must render a disabled/greyed style when onTap == null
       : () {
           setState(() => _sendingRequestIds.add(data.id!));
           sendRequestRx.sendRequest(id: data.id!).waitingForSuccess().then((success) {
             if (!mounted) return;
             setState(() => _sendingRequestIds.remove(data.id!));
             if (success) {
               ToastUtil.showSuccessMessage("Friend request sent");
               searchUserRx.searchUser(search: _searchController.text);
             }
           });
         },
   ```
3. **Check `CustomButton`** (`app/lib/common_widget/…`): if it does not already render a disabled/greyed appearance when `onTap == null`, add that (reduced opacity / muted fill). This is the "grey" the tester asked for. If adding a disabled style is non-trivial, swap to showing a non-interactive "Requested" chip while `_sendingRequestIds.contains(id)`.
4. Optional polish: relabel the `isRequestSent` **Cancel** button (L230) to read "Requested" with a small cancel affordance, so the state reads as "already sent" rather than an action. Confirm the wording with Achia before changing — keep the cancel capability.

**Tests:** widget-level is optional here (mostly visual). At minimum verify `flutter analyze` clean. If `CustomButton` gains a disabled state, add a widget test that a null `onTap` renders the disabled style.

**Acceptance:** rapid double-tap on Send Request fires exactly one `sendRequest`; button is visibly greyed while in flight and shows the sent/Requested state afterward.

---

## QW2 — Search by username only

**Feedback:** Tomer — "when searching for friends you see everyone, that makes no sense — should be by username only."

**Current behavior:**
- Client `search_screen.dart` calls `searchUserRx.searchUser(search: "")` on open (L37-40), on close-search (L55-63), and on dispose (L44-49) → loads the **entire** user directory. Per-keystroke search is `_onSearchChanged` (L66-68).
- Backend `UserService::userList` (`backend/app/Services/UserService.php:48-106`): empty `search` returns **all** users (`->when($search, …)` skips the filter); non-empty matches `first_name`, `last_name`, `username`, `phone`, and `CONCAT(first_name,' ',last_name)` — all `LIKE %term%` (L82-93). Route `GET /user-list` (`backend/routes/api.php:79`), controller `UserController::userList` (L73-93), param name `search`, no validation. **Only this one screen consumes the endpoint** (group flows use the friends list, not `/user-list`), so a focused change is safe.

**Change (product intent: username-only discovery, no full-directory browse):**

_Backend (`UserService::userList`):_
1. Match **username only**. Replace the multi-field `orWhere` block (L84-90) with a single `->where('username', 'like', "%{$search}%")` (keep it inside the existing nested closure and the `id != me` exclusion).
2. **Return no results for an empty/blank query** instead of the whole directory — discovery must require a username. Trim the term and short-circuit:
   ```php
   $search = trim((string) $request->get('search', ''));
   if ($search === '') {
       // return an empty paginator in the same envelope shape
   }
   ```
   Keep the response envelope and `UserListResource` shape identical (empty `data` list) so the client needs no shape change.
3. Consider adding a `UserListRequest` FormRequest (`App\Http\Requests\User\UserListRequest`) per convention R7 if you add any rules (e.g. `search` string, `per_page` int, max length). Optional but cleaner than reading raw `$request`.

_Client (`search_screen.dart`):_
4. Stop auto-loading everyone. Remove/replace the `searchUser(search: "")` call in `initState` (L37-40) so the screen opens **empty**.
5. Add a friendly empty/prompt state where the "No users found" `Center` currently is (L117-119): when `_searchController.text.trim().isEmpty`, show "Search for a friend by their username" instead of a results list. Only call `searchUser` once the query is non-empty (optionally require ≥ 2 chars, debounced — a debounce likely already exists in `_onSearchChanged`; confirm).
6. The reset calls in `dispose`/`_toggleSearch` can stay (they now clear to an empty result set, which is the desired idle state).

**Copy:** update the search field hint/placeholder to "Search by username".

**Tests (required):**
- Backend: add cases to `backend/tests/Feature/User/UserListingTest.php` — (a) matches by `username`, (b) **does not** match by `first_name` / `last_name` / `phone`, (c) empty `search` returns an empty list (not all users), (d) self still excluded. Assert `assertOk()` + `assertJsonPath('success', true)`.
- Client: if the `searchUser(...)` URL/params are unchanged, `app/test/networks/endpoints_test.dart` stays green; add/adjust a case in `app/test/features/search/data/rx_search_user/rx_test.dart` if you change when `searchUser` is called.

**Acceptance:** opening the add-friend screen shows a prompt, not a list; typing a partial username returns username matches only; name/phone no longer surface strangers.

**Decision flag for Achia:** dropping **phone** matching removes "find friends by phone number" discovery. Confirm that's intended. If phone-based discovery should survive, implement as a `mode=username` param (default = current behavior) instead of a global change — noted here so Claude Code asks before removing phone matching.

---

## QW3 — Return to the intro/explainer from login

**Feedback:** Kobi — after reaching login/signup you can't get back to the pre-signup explainer pages, even after force-quitting.

**Current behavior:** `app/lib/features/onboard/presentation/on_board_screen.dart` last-slide button (L155-171) writes `appData.write(kKeyIsFirstTime, false)` then `NavigationService.navigateToReplacementUntil(Routes.loginScreen)` — a stack-clearing replace, and `kKeyIsFirstTime=false` means the carousel never shows again on next launch. The login screen (`app/lib/features/auth/presentation/login/login_screen.dart`) has **no AppBar and no back affordance**; header is logo + "Login" / "Login to continue" (L77-97). There is **no named route for onboarding** (`RouteGenerator` doesn't register it; it's the bootstrap home screen gated on `kKeyIsFirstTime`), so you can't just `navigateTo` it.

**Change (lowest-risk, no route-table surgery):** make `OnBoardScreen` re-openable as a normal pushed page from login.

1. Add an optional flag to `OnBoardScreen`:
   ```dart
   final bool fromLogin;
   const OnBoardScreen({super.key, this.fromLogin = false});
   ```
2. In the last-slide `onPressed` (L155-171) **and** the Skip handler (L133-142): when `fromLogin == true`, just `NavigationService.goBack()` (pop back to login) and do **not** touch `kKeyIsFirstTime` or call `navigateToReplacementUntil`. Preserve the existing behavior when `fromLogin == false`.
3. On the login screen header (near the logo, ~L77-98), add a subtle text button: **"How Reacti works"** →
   ```dart
   Navigator.of(context).push(
     MaterialPageRoute(builder: (_) => const OnBoardScreen(fromLogin: true)),
   );
   ```
   Style it to match the existing login links (the "Sign up" / forgot-password `TextButton`/`RichText` in this file).

**Why this approach:** avoids editing `RouteGenerator`/`Routes` and avoids resetting `kKeyIsFirstTime` (which would re-trigger the first-run flow on next launch). The carousel becomes a reviewable page without changing first-run semantics.

**Tests:** widget test optional; ensure `flutter analyze` clean. Manually verify the carousel's "Get Started"/Skip both simply pop back to login when opened this way, and that normal first-run still routes to login and sets the flag.

**Acceptance:** from login, a user can open the explainer, page through it, and return to login; first-run behavior is unchanged.

---

## QW4 — Tap profile photo to enlarge

**Feedback:** Shai — tap to enlarge the profile photo (editing your own already exists).

**Current behavior:** `app/lib/features/profile/presentation/profile_screen.dart` (L79-94) renders the avatar as a bordered `Container > ClipOval > CustomNetworkImage(urls: data?.avatar ?? "")` with **no tap**. A reusable full-screen viewer already exists: `app/lib/features/chat/presentation/full_screen_image_viewer.dart` — `FullScreenImageViewer({required String url})` (pinch-zoom `InteractiveViewer`, black scaffold, close button). It takes a **network URL string**, which is exactly what `data?.avatar` is.

**Change:**

1. Wrap the avatar `Container` (L79-94) in a `GestureDetector` (or `InkWell`), only tappable when there's an avatar:
   ```dart
   GestureDetector(
     onTap: (data?.avatar ?? "").isEmpty
         ? null
         : () => Navigator.of(context).push(
               MaterialPageRoute(
                 builder: (_) => FullScreenImageViewer(url: data!.avatar!),
               ),
             ),
     child: Container( /* existing avatar */ ),
   );
   ```
2. Add the import for `full_screen_image_viewer.dart`.
3. Edit-your-own already works via the existing camera-icon `InkWell` on the edit-profile screen — **leave it as is**; enlarge is a separate gesture (tap the photo = enlarge; the pencil/camera icon = edit).

**Optional (confirm scope with Achia):** apply the same tap-to-enlarge to other users' profile avatars if a view-contact screen exists. Keep the base PR to the user's own profile.

**Tests:** `flutter analyze` clean; a widget test asserting a tap on the avatar pushes `FullScreenImageViewer` is a nice-to-have.

**Acceptance:** tapping your profile photo opens a zoomable full-screen view; empty-avatar case does nothing; editing still works via the icon.

---

## QW5 — Privacy reassurance on the contacts prompt

**Feedback:** Kobi & Tomer — the contacts screen doesn't say whether it stores your contacts; add a data-privacy note so people are comfortable granting access.

**Current behavior:** `app/lib/features/friends/presentation/find_screen.dart` → `_buildContactsIntro()` (L343-392) shows an icon, title "Find friends from your contacts", subtitle "See which of your contacts are already on Reacti.", primary "Find friends" (`_requestAndLoad`), secondary "Not now" (`_skipContacts`). Styling uses the legacy `AppColors` + `TextFontStyle.*` (dark screen).

**⚠️ Prerequisite (blocking):** confirm what the backend actually does with uploaded contacts before writing reassurance copy. Check the contacts-sync endpoint/handler (grep backend for the contacts match route and its controller/service) and confirm whether phone numbers are **stored** or only **matched in-memory and discarded**. **Do not ship a "we never store your contacts" claim unless the code backs it.** If contacts are stored, write accurate copy instead (e.g. "used only to find friends; hashed/stored securely" per what's true) and flag the finding to Achia in the PR description.

**Change:** insert one reassurance `Text` inside the existing `if (!_skipped)` block, after the subtitle and before the `SizedBox(height: 16.h)`, matching the subtitle style:
```dart
SizedBox(height: 8.h),
Text(
  // Final wording depends on the backend finding above.
  "We only use your contacts to find friends on Reacti — we don't store them.",
  textAlign: TextAlign.center,
  style: TextFontStyle.headline14w400C666666Poppins,
),
```

**Tests:** none required (static copy). `flutter analyze` clean.

**Acceptance:** the contacts prompt shows an accurate privacy line; wording matches verified backend behavior.

---

## QW6 — Camera flash / torch toggle

**Feedback:** Shai — control the flash from the camera.

**Current state (`app/lib/features/chat/presentation/camera_capture_screen.dart`):** package `camera: ^0.12.0+1`. State class `_CameraCaptureScreenState` (L50) holds `_isVideoMode`, `_isRecording`, etc. (L52-58). Controller created in `_initController(index)` (L105-139), `initialize()` at L128; `_initController` runs on first setup, on flip (`_flipCamera`, L149), and on resume (L82). Capture UI `build()` (L175-214): close button top-left (L184-192); bottom controls Column (L194-210) with `_modeToggle()` and `_bottomRow()`. `_bottomRow()` (L273-299) = `[Spacer(), _shutter(), flip button]`; the **left slot is a bare `Spacer()` (L278)**. No flash anywhere.

**Change:**

1. Add flash state next to the mode flags (after L55):
   ```dart
   FlashMode _flashMode = FlashMode.off; // FlashMode comes from package:camera (already imported)
   ```
2. Re-apply flash after every (re)initialize so it survives flips/resume — immediately after L128 (`await controller.initialize()…`):
   ```dart
   await controller.setFlashMode(_flashMode);
   ```
3. Add a toggle handler:
   ```dart
   Future<void> _toggleFlash() async {
     const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
     final next = order[(order.indexOf(_flashMode) + 1) % order.length];
     await _controller?.setFlashMode(next);
     if (!mounted) return;
     setState(() => _flashMode = next);
   }
   ```
   (Off → Auto → Always cycle for photos. If you prefer a simple on/off torch for parity across photo+video, use `FlashMode.torch`/`FlashMode.off` instead — pick one and keep the icon in sync.)
4. Add the button by replacing the left `Spacer()` in `_bottomRow()` (L278) with a flash `IconButton`, mirroring the flip button's structure on the right, with an icon reflecting `_flashMode` (`Icons.flash_off` / `Icons.flash_auto` / `Icons.flash_on`). Alternatively place it top-right in the `SafeArea` (top-left is the close button). Keep it hidden while `_isRecording` if using photo flash modes.

**Edge cases:** front camera has no flash on most devices — `setFlashMode` may throw; wrap in try/catch and hide/disable the button when the active camera doesn't support flash (front-facing). Verify behavior in both photo and video modes.

**Tests:** manual on-device (simulator has no torch). `flutter analyze` clean.

**Acceptance:** a flash control is visible on the capture screen, cycles modes, persists across camera flips, and photos/video honor it; front camera degrades gracefully.

---

## QW7 — Discarding a photo re-opens the camera

**Feedback:** Shai — if I cancel a photo from the camera it returns me to the chat; it should return to the camera.

**Current flow:**
- `app/lib/features/chat/presentation/media_picker_mixin.dart` `_openCamera` (L64-73): pushes `CameraCaptureScreen`, receives a `CameraCaptureResult?`; `null` → return; otherwise `await _confirmAndStage(...)`.
- `camera_capture_screen.dart` `_capture()`: pops the file (photo L168, video L160); the close button pops nothing (`null`). So the camera route is **already gone** once preview opens.
- `_confirmAndStage` (L77-92): pushes `MediaPreviewScreen`, and on `confirmed == true` stages the file; otherwise does nothing → control unwinds to the **chat**.
- `media_preview_screen.dart`: discard/X pops `false` (L77); "Use" pops `true` (L87).

**Change:** loop in `_openCamera` so discard re-opens the camera, while "Use" and closing the camera both exit.

1. Make `_confirmAndStage` report the outcome — change its signature to `Future<bool>` returning `confirmed == true` (it currently swallows the result).
2. Rewrite `_openCamera`:
   ```dart
   Future<void> _openCamera(BuildContext context) async {
     while (true) {
       final result = await Navigator.of(context).push<CameraCaptureResult>(
         MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
       );
       if (result == null) return;               // user closed the camera → back to chat
       if (!context.mounted) return;
       final staged = await _confirmAndStage(context, result.file, result.mediaType);
       if (staged) return;                        // "Use" → staged, done
       // discarded → loop re-opens a fresh camera
     }
   }
   ```

**Notes / risks (from tracing the stack):**
- The camera is popped before preview is pushed, so re-pushing is a fresh route — **no stack accumulation**, no back-button loop.
- Termination is well-defined: preview-X (`false`) → re-open camera; camera-X (`null`) → exit to chat. Make sure Achia is fine with the UX contract: "discard photo = back to camera; to leave entirely, press X on the camera." Add a brief note in the PR.
- `CameraCaptureScreen` builds a fresh `CameraController` per push and disposes it in `dispose()` (L70), so repeated re-opens are safe. Re-check `context.mounted` each iteration (done above).

**Tests:** manual on-device (camera). `flutter analyze` clean. If any mixin-level unit test exists for staging, update it for the new `Future<bool>` return.

**Acceptance:** capture → discard returns to a live camera; capture → Use stages the media; camera X returns to chat.

---

## QW8 — Haptics (and light sounds) for send / receive

**Feedback:** Shai — add sounds and vibration in response to things happening in the app.

**Current state:** **no haptics or sound anywhere** in `app/lib` (no `HapticFeedback`, `SystemSound`, vibration, or audio package). `pubspec.yaml` has an `assets:` section (icons/images/fonts) but **no `assets/sounds/`**. `HapticFeedback`/`SystemSound` from `package:flutter/services.dart` need **no new dependency**; custom sound files would need an audio package + a new assets entry.

**🚨 Guardrail — do not add feedback to the silent-recording path.** The patented flow is *silent* front-camera capture when a recipient opens media (`receiver_message_widget.dart` → `recordVideoSilently()`, reaction upload ~L427/L461). **Never** trigger a vibration or sound when a reaction is *captured on the recipient side* — that would defeat the "silent" guarantee. Keep QW8 to the two safe surfaces below. This keeps the PR clear of the CLAUDE.md regression-test mandate (which binds only to changes in the blur/record/reaction-upload/mark-viewed path).

**Change (scope this PR to built-in haptics; treat custom sounds as optional stretch):**

1. Add a tiny central helper, e.g. `app/lib/helpers/feedback_service.dart`:
   ```dart
   import 'package:flutter/services.dart';

   class FeedbackService {
     static bool _enabled = true; // wire to a setting, see step 4
     static void setEnabled(bool v) => _enabled = v;

     static void messageSent() {
       if (!_enabled) return;
       HapticFeedback.lightImpact();
     }

     static void messageReceived() {
       if (!_enabled) return;
       HapticFeedback.selectionClick();
     }
   }
   ```
2. **Message sent** — call `FeedbackService.messageSent()` in the composer send entry point `_handleSend()` in `app/lib/features/chat/presentation/widget/send_message_widget.dart` (~L280, right after the empty-check / optimistic echo). This covers 1:1 and group (both route through here).
3. **Message / reaction received** — call `FeedbackService.messageReceived()` in the realtime `onEvent` handlers, next to the existing analytics hook `trackMessageReceived(...)`:
   - `inbox_screen.dart` ~L399-404
   - `group_inbox_screen.dart` `onEvent` ~L426
   - (optional) `chat_screen.dart` ~L130
   Only fire when the incoming event is a genuinely new inbound message (not an echo of your own send, not a read-receipt update) — branch on the parsed message type/sender so you don't buzz on your own outgoing messages.
4. **Respect a user setting.** Follow the existing `kKeyReadReceipts` pattern: add `kKeySoundHapticsEnabled` to `app/lib/constants/app_constants.dart` (default `true`), read it into `FeedbackService._enabled` at startup, and add a toggle in the settings/profile screen alongside the existing read-receipts toggle. Some users find haptics annoying — make it switch-off-able from day one.

**Optional stretch (separate follow-up, not required for this PR):** custom notification sounds. Would need an audio package (`audioplayers`) + `assets/sounds/` registered in `pubspec.yaml` + sound files. Recommend deferring; ship haptics first, evaluate on device, then decide if sounds add enough.

**Tests:** unit-test `FeedbackService` respects the `_enabled` flag (guard around the platform call). Keep platform-channel calls behind the helper so they're easy to stub. `flutter analyze` clean.

**Acceptance:** sending buzzes lightly; receiving a new inbound message/reaction gives a subtle tick; your own outgoing messages don't double-buzz; the recipient's silent capture stays silent; a settings toggle disables all of it.

---

## Cross-cutting checklist (per PR)

- [ ] Branch off `develop`, named per table above.
- [ ] `dart format .` + `flutter analyze` clean (app PRs); `./vendor/bin/pint` clean (QW2 backend).
- [ ] Tests added/updated where noted (required for QW2; encouraged elsewhere).
- [ ] Required CI checks green (`Analyze & Test`, and `PHP Tests` for QW2).
- [ ] No new dependency except where explicitly allowed (none required for QW1–QW8; QW8 stretch sounds only).
- [ ] Conventional-commit messages; PR description states the change and, for QW1/QW2/QW7, the UX/decision note flagged for Achia.
- [ ] Screenshot or screen-recording attached for on-device review.

## Open decisions to surface to Achia (don't block coding the rest)

1. **QW2** — is removing **phone-number** discovery intended, or should search stay multi-field with a `mode=username` option? (Default plan: username-only.)
2. **QW5** — depends on the backend contacts finding; final privacy wording must match what the code actually does.
3. **QW7** — confirm the "discard = back to camera, camera-X = back to chat" UX contract.
4. **QW1 / QW8** — exact button wording ("Requested") and whether haptics default on.
