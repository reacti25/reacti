# Code-quality backlog

Problems and improvements observed while documenting and refactoring
the Reacti codebase. **Nothing here has been fixed** — the refactor so
far was strictly behaviour-preserving. This file is the to-do list for
the *next* phase, when changing functionality is allowed.

Each item: **[severity]** location — problem — suggested change.
Severity: `CRITICAL` (security / data loss), `HIGH` (broken feature or
wrong behaviour), `MEDIUM` (quality / maintainability), `LOW` (polish).

---

## 1. Security

* **[CRITICAL]** `app/lib/main.dart` — `MyHttpOverrides` overrides
  `badCertificateCallback` to return `true` for every certificate,
  disabling TLS validation app-wide, including production. This makes
  every API call MITM-able. Remove the override; if a specific dev
  host needs it, scope it to debug builds + that host only.
* **[CRITICAL]** OTP codes are returned in API response bodies.
  `PasswordResetService::forgotPassword` / `resendOtp` and
  `AuthService::resendRegisterOtp` put `'otp' => $otp` in the JSON
  (the code even comments `// remove in production`). Anyone who can
  call `forgot-password` for an email gets that account's reset OTP →
  full account takeover. Stop returning the OTP; deliver it only by
  email.
* **[MEDIUM]** Hardcoded Pusher credentials in the Flutter app — the
  Pusher key, host, and the `https://reacti.io/api/broadcasting/auth`
  URL are inlined in `chat_screen.dart` and `inbox_screen.dart`
  (duplicated). Move them to config / `--dart-define` env, like the
  API base URL. (Behavior/config change — kept out of the frontend
  refactor; see `docs/refactor/frontend-refactor-plan.md`.)
* **[MEDIUM]** `backend/composer.json` was reconstructed from
  `composer.lock` (see root `CLAUDE.md`). Verify it matches the
  delivery archive's original before trusting dependency parity.
* **[MEDIUM]** `FindFriendController::findContacts` builds a
  `DB::raw` subquery with `{$user->id}` interpolated. It is an
  integer id so not exploitable today, but the pattern is fragile —
  use a binding or an Eloquent join.

## 2. Correctness bugs (wrong behaviour, preserved by the refactor)

* **[HIGH]** `SingleChatController::typingStatus` dispatches
  `new \App\Events\UserTypingEvent(...)` — that class does not exist
  (the real one is `App\Events\Chat\V2\UserTypingEvent`). Every call
  to `POST /v2/auth/chat/typing/{id}` 500s. One-line fix: correct the
  reference / `use`.
* **[HIGH]** Social login is entirely dead. Route
  `social/signin/{provider}` points at `SocialLoginController::
  socialSignin`, which does not exist; the real method
  `googleAuthentication` is unrouted. And `SocialAuthService::
  googleAuthenticate` writes `name` + `is_otp_verified` columns that
  are not on the `users` table (it has `first_name`/`last_name`,
  `otp_verified_at`) → it would throw on first use anyway. Decide:
  wire it up correctly or delete it.
* **[HIGH]** `Helper::deleteImage()` contains a stray `dd("jalis")`
  debug call in its empty-input branch — root `CLAUDE.md` explicitly
  forbids leftover `dd()`. Remove it.
* **[HIGH]** `ProfileController` (web, Settings) `UpdateProfile`
  assigns `$user->name`, but `users` has no `name` column → the save
  throws, is swallowed, and the endpoint silently never updates
  anything. Assign `first_name`/`last_name`.
* **[HIGH]** 5 `AdminGroupChatController` routes (`editMessage`,
  `addMembers`, `removeMember`, `makeAdmin`, `deleteMessages`) point
  at controller methods that don't exist. Implement or remove.
* **[MEDIUM]** `UserController::userDetais` returns HTTP **200** with
  `"User not found."` for a missing user — should be 404.
* **[MEDIUM]** `NotificationController` (`allNotifications`,
  `readNotification`, `readAllNotifications`) has no routes — it is
  unreachable dead code. Wire it up or delete it.
* **[MEDIUM]** `FirebaseTokenController::store` / `deleteToken` do
  `$x = FirebaseTokens::where(...)` then `if ($x)` — a query builder
  is always truthy, so the "delete if exists" always runs and
  `deleteToken`'s 404 branch is dead. Use `->exists()` / `->first()`.
* **[MEDIUM]** `ChatManageController::room()` resolves the user via
  the `api` guard while the rest of that controller uses the `web`
  guard — almost certainly a copy-paste slip.
* **[MEDIUM]** `UserProfileController::deleteProfile` hard-deletes the
  account (the `User` model has no `SoftDeletes` trait, despite the
  migration having a `deleted_at` column and several queries doing
  `whereNull('deleted_at')`). Decide: add `SoftDeletes` to the model
  (so those `whereNull` filters actually work) or drop the column.
* **[MEDIUM]** Flutter `rx_edit_profile/api.dart` maps the `bio`
  argument onto the backend form key `dob` — a field-name mismatch;
  editing a bio likely writes the wrong field.
* **[LOW]** 4 unrouted `Web\Backend` controllers are dead code
  (see `docs/testing/inventory.md` §8). `TermsAndPolicyController` is
  an empty stub. Remove or implement.
* **[LOW]** `App\Services\ChatFileService` is orphaned — a complete
  file-upload + thumbnail service that nothing references. The chat
  services upload via `Helper::fileUpload` / inline `Storage::disk('s3')`
  instead. Either adopt `ChatFileService` everywhere (it would unify
  file handling — but note it stores to the `public` disk, while
  `SingleChatService` uses `s3`, so adopting it is a *functionality*
  change) or delete it.
* **[LOW]** `ChnagePasswordApi` (Flutter) — class name is misspelled.
* **[LOW]** Several `should_show_blur` / `is_blurred` / `is_viewed`
  flags are loosely typed (API sends `1`/`0`, bool, or string). Pick
  one representation and cast consistently.

## 3. Architecture & code quality

* **[HIGH]** v1 `ChatController` (`auth/chat/*`) and v2
  `SingleChatController` (`v2/auth/chat/*`) are near-duplicate chat
  implementations. Two code paths for the same feature is a
  maintenance trap and a patent-flow risk. Pick one, migrate clients,
  retire the other.
* **[MEDIUM]** The new service classes are large — `SingleChatService`
  is ~1000 lines. The CP1-6 refactor was a mechanical extraction, not
  a decomposition. Break the big services into cohesive units; methods
  are still long and multi-purpose.
* **[MEDIUM]** Services reach directly for facades (`Cache`, `Mail`,
  `DB`, `Auth`, `Storage`). That works but makes isolated unit
  testing hard. Inject collaborators (or wrap them) so services are
  testable without booting the framework.
* **[MEDIUM]** Validation is still inline (`Validator::make` /
  `$request->validate`) in every controller. The refactor kept it
  there on purpose (Form Requests would change the 422 body shape).
  Migrate to Form Requests *and* standardise the 422 body in the same
  pass.
* **[MEDIUM]** Response-envelope inconsistency: most endpoints use the
  `ApiResponse` trait, some build bespoke `response()->json()`. Worse,
  the trait keys success as `success` but failure as `status` — an
  asymmetry the client must special-case. Standardise one envelope.
* **[LOW]** No DTOs / value objects — raw associative arrays are
  passed between controller and service. Typed objects would catch
  shape mistakes at the boundary.
* **[LOW]** Eloquent queries are built inline in service methods.
  Common ones (friend-id gathering from both directions, unread
  scopes) should be model scopes / query objects.
* **[LOW]** Dead commented-out code blocks exist throughout
  (controllers, Flutter widgets). The refactor removed a few; sweep
  the rest.

## 4. Performance

* **[MEDIUM]** Pusher broadcasts and the Firebase push fan-out run
  synchronously inside the request (`send`, `sendMessage`,
  `forwardMessage`). A slow FCM call delays the user's response.
  Move push delivery to queued jobs.
* **[MEDIUM]** Mail is sent synchronously (`Mail::to()->send(...)` in
  the OTP / verification flows). Queue it (`ShouldQueue`) so register
  / forgot-password responses don't block on SMTP.
* **[MEDIUM]** `NotificationController::allNotifications` does
  `->get()` on unread notifications with no limit — unbounded result
  set. Paginate it.
* **[LOW]** `listCombined` calls `Room::firstOrCreate` per user — a
  write during a read, and a potential N+1. Review.
* **[LOW]** No caching strategy beyond the registration/OTP cache —
  hot read endpoints (chat list, profile) could benefit.

## 5. Testing & tooling

* **[MEDIUM]** Tests are HTTP feature tests only. The extracted
  services have no isolated unit tests — add them now that logic is
  in services.
* **[MEDIUM]** No static analysis. Add PHPStan / Larastan to CI.
* **[MEDIUM]** `pint` is not an enforced CI check — formatting can
  drift. Gate it.
* **[MEDIUM]** No coverage threshold. CI runs coverage but does not
  fail below a floor — set one and ratchet it up.
* **[MEDIUM]** The Flutter app is barely tested (~5 test files). The
  per-endpoint `rx_*` data sources can't be unit-tested without a
  production change (they are `final` and use non-injectable
  `*.instance` HTTP singletons) — see `docs/testing/inventory.md` §8.
  Constructor-inject Dio / the api singletons to unblock this.
* **[LOW]** Branch-protection path filters mean a backend-only or
  app-only PR leaves one required check unreported, forcing
  `--admin` merges. Make both checks always report (e.g. a no-op
  success job) so protection works without admin override.

## 6. Notes for whoever picks this up

* The CP1-6 refactor (`docs/refactor/backend-refactor-plan.md`) put
  all API business logic into `app/Services/*`. Fix bugs in the
  service now, not the controller.
* Pre-existing behaviour — including every bug above — is pinned by
  the test suite. Fixing a bug will (correctly) break the test that
  pinned the old behaviour; update that test in the same PR.
* The patent flow (silent front-camera recording on `mark-viewed`)
  is load-bearing — see root `CLAUDE.md`. Re-run the patent suites
  after any change near `send` / `markAsViewed` / the blur flags.
