# Code-quality backlog

Problems and improvements observed while documenting, refactoring, and
reviewing the Reacti codebase. **Nothing here has been fixed** — the
refactor work so far was strictly behaviour-preserving. This file is the
to-do list for the *functionality phase*, when changing behaviour is
allowed.

Each item: **[severity]** location — problem — suggested change.
Severity: `CRITICAL` (security / data loss / legal), `HIGH` (broken
feature or wrong behaviour), `MEDIUM` (quality / maintainability),
`LOW` (polish).

Last full review: 2026-05-18 (backend, app, and project-level sweep).

---

## 1. Security

* **[CRITICAL]** `backend/routes/web.php` lines 15-100 — eight
  **unauthenticated** maintenance routes are publicly reachable with no
  auth, no admin gate, and no environment guard: `/run-migrate` and
  `/run-migrate-fresh` both call `migrate:fresh` (drops every table),
  `/run-composer-update` runs `shell_exec('composer update')`, plus
  `/run-db-seed`, `/run-optimize-clear`, `/run-cache-clear`,
  `/run-queue-restart`, `/run-storage-link`. Anyone who knows the URL
  can **wipe the production database** or run arbitrary composer
  resolution. Delete these routes. If browser-triggered migration is
  genuinely needed, gate it behind `auth` + `admin` **and**
  `app()->environment('local')`.
* **[CRITICAL]** No rate limiting anywhere on auth/OTP. `routes/api.php`
  `/login`, `/register`, `/resend-register-otp`, `/forgot-password`,
  `/verify-otp`, `/resend-otp` have **no `throttle` middleware**. The
  OTP is a 4-digit code (10,000 combinations) — `verify-otp` is
  brute-forceable in seconds. Add `throttle:` to every auth/OTP route
  (e.g. `throttle:6,1` on OTP verification) and an attempt counter on
  the cached OTP that invalidates it after N misses.
* **[CRITICAL]** OTP codes are returned in API response bodies.
  `PasswordResetService::forgotPassword` / `resendOtp` and
  `AuthService::resendRegisterOtp` put `'otp' => $otp` in the JSON
  (the code even comments `// remove in production`). Anyone who can
  call `forgot-password` for an email gets that account's reset OTP →
  full account takeover, made trivial by the missing rate limiting
  above. Stop returning the OTP; deliver it only by email.
* **[CRITICAL]** `app/lib/main.dart` — `MyHttpOverrides` overrides
  `badCertificateCallback` to return `true` for every certificate,
  disabling TLS validation app-wide, including production. This makes
  every API call MITM-able. Remove the override; if a specific dev
  host needs it, scope it to debug builds + that host only.
* **[CRITICAL]** Auth token stored unencrypted and never cleared on
  logout. The app persists `kKeyAccessToken` / `kKeyFCMToken` /
  `kKeyUserId` via `GetStorage` (a plaintext JSON file). `totalDataClean()`
  in `app/lib/networks/stream_cleaner.dart` only sets
  `kKeyIsLoggedIn=false` — it never erases the token, and `DioSingleton`
  keeps its `Bearer` header until the app restarts. Move the token to
  `flutter_secure_storage`; on logout actually erase token / user id /
  FCM token and rebuild the Dio client unauthenticated.
* **[HIGH]** File-upload validation is weak across all media endpoints.
  `ChatController::send` (v1) accepts `'file' => 'nullable'` — no
  `file`, `mimes`, or `max`. `GroupCreateController::createGroup` /
  `updateAvatar` / `GroupMessageController::sendMessage` cap size but
  have **no `image`/`mimes` rule**, so a `.php`/`.svg`/`.html` upload
  passes. `Helper::fileUpload` then writes it under web-served
  `public/uploads/` with `mkdir(0777)` → stored XSS / RCE. Add
  `mimes:` + size caps to every upload rule and store uploads in
  `storage/` or S3, never the web root; use `0755`.
* **[HIGH]** `config/cors.php` — `allowed_origins`, `allowed_methods`,
  `allowed_headers` are all `['*']` on an authenticated API. Restrict
  `allowed_origins` to the known app/admin domains.
* **[HIGH]** `backend/routes/backend.php` — the `ProfileController`,
  `FirebaseController`, `SocialController`, `SettingController`,
  `DynamicPageController` route groups sit **outside** the in-file
  `auth`+`admin` group and are protected only by the `then:` closure in
  `bootstrap/app.php`. Editing that closure would silently make admin
  settings public. Move them explicitly inside the `auth`+`admin` group.
* **[HIGH]** `GroupCreateController::createGroup` and the OTP/reset
  handlers return `$e->getMessage()` / `$e->getLine()` verbatim in the
  JSON body — leaks file paths and SQL. With `APP_DEBUG=true` (see §11)
  this is doubly bad. Return a generic message; log the detail.
* **[MEDIUM]** Hardcoded Pusher credentials in the Flutter app — Pusher
  key `d3d9ba606e9065ff0c3d1d566ccf904c`, host
  `climbiq-goonclimbers.com`, port `8081`, and the
  `https://reacti.io/api/broadcasting/auth` URL are inlined in
  `app/lib/features/chat/data/chat_realtime_service.dart`. (The
  refactor relocated these here from `chat_screen.dart`/`inbox_screen.dart`.)
  The host does not match the API host (`reacti.io`) — verify it is
  correct. Move all of it to `--dart-define` / config.
* **[MEDIUM]** `Helper::fileUpload` / `uploadImage` `mkdir(..., 0777,
  true)` creates world-writable directories. Use `0755` and the
  `storage` disk.
* **[MEDIUM]** `User::$fillable` includes security-sensitive columns
  (`otp`, `otp_verified_at`, `reset_password_token`, `status`,
  `is_google_signin`, `google_id`). Safe today (callers pass
  `validated()`), but one future `User::update($request->all())` lets a
  client self-verify, set its own reset token, or flip `status`. Remove
  those columns from `$fillable`.
* **[MEDIUM]** `FirebaseTokens` model uses `$guarded = []` with no
  `$fillable` — every column including `id`/`user_id` is mass-assignable
  and `store()` takes request input. Use an explicit `$fillable`.
* **[MEDIUM]** `AuthService` mixes `random_int()` and `rand()` for OTP
  generation; `rand()` is not cryptographically secure. Use
  `random_int()` for all OTPs / reset tokens.
* **[MEDIUM]** `app/lib/networks/dio/log.dart` — `onRequest`/`onResponse`
  log full headers (including `Authorization: Bearer …`) and bodies and
  are **not** gated by `kDebugMode` (only `onError` is). Login tokens
  and OTP-bearing payloads are written to device logs in release
  builds. Gate all logging on `kDebugMode`; redact `Authorization` /
  password / OTP fields.
* **[MEDIUM]** `routes/channels.php` `Log::info`s every websocket
  channel-auth attempt with `user_email` — PII written to disk on every
  subscribe. Remove or downgrade to `debug`.
* **[MEDIUM]** `GET /api/test-s3` (inside `auth:api`) writes/reads/deletes
  a real object in the production S3 bucket on every call and leaks the
  bucket URL; `GET /api/check`, `firebase/test` are diagnostic routes
  shipped to production. Remove or guard to local env.
* **[MEDIUM]** `backend/composer.json` was reconstructed from
  `composer.lock` (see root `CLAUDE.md`). Verify it matches the
  delivery archive's original before trusting dependency parity. This
  is also the root cause of CI running `composer update` (see §10).
* **[MEDIUM]** `FindFriendController::findContacts` builds a `DB::raw`
  subquery with `{$user->id}` interpolated. An integer id, so not
  exploitable today, but the pattern is fragile — use a binding or an
  Eloquent join. Also: `contacts.*` is validated only as `string` with
  no array `max`, so a client can upload an unbounded phone list to
  enumerate which numbers are registered — add `array|max:1000`.
* **[MEDIUM]** `config/session.php` `secure` cookie defaults to an unset
  env var → `null` → session cookies sent over HTTP. Set
  `SESSION_SECURE_COOKIE=true` for production.
* **[LOW]** Several IDOR-adjacent `exists:` rules are unscoped:
  `SingleChatController::send` validates `reply_to_id` as
  `exists:chats,id` (any message in the system), `GroupMessageController`
  validates `reply_to_message_id` as `exists:group_messages,id` without
  checking group membership, and `forwardMessage` does not verify the
  caller was party to the forwarded message. Scope the `exists` rules
  to the room/group and verify ownership before copying content.
* **[LOW]** `social/signin/{provider}` takes a free `{provider}` path
  param with no `in:google,apple` whitelist — provider-injection risk
  once social login is wired. Constrain the route param.

## 2. Privacy & legal

* **[CRITICAL]** No user consent or disclosure for the silent
  front-camera recording. When a recipient taps "Click to view the
  media" (`receiver_message_widget.dart` → `_buildBlurPlaceholder` →
  `recordVideoSilently`), the front camera records a ~4-second clip
  **with audio** and uploads it, with zero indication to the user. This
  is the patent-protected feature and must not simply be removed — but
  covertly recording a user's face and voice with no consent UX, no
  privacy-policy linkage at the capture point, and no opt-out is a
  GDPR / biometric-privacy liability and a likely App Store rejection
  (iOS `NSCameraUsageDescription` must reflect actual use). Resolve
  **with product + legal**: add an explicit one-time consent flow and/or
  a visible recording indicator, document the behaviour in the privacy
  policy, and surface it at the point of capture. Track as a release
  blocker, not a code cleanup.
* **[LOW]** `recorder.dart` selects the Android front camera as
  `cameras.last` — on devices with multiple/back/external cameras this
  can record the wrong camera. Filter by `CameraLensDirection.front` on
  Android (as iOS already does).

## 3. Correctness bugs (wrong behaviour, preserved by the refactor)

* **[HIGH]** `SingleChatController::typingStatus` dispatches
  `new \App\Events\UserTypingEvent(...)` — that class does not exist
  (the real one is `App\Events\Chat\V2\UserTypingEvent`). Every call to
  `POST /v2/auth/chat/typing/{id}` 500s. One-line fix: correct the
  reference / `use`.
* **[HIGH]** Social login is entirely dead. Route
  `social/signin/{provider}` points at
  `SocialLoginController::socialSignin`, which does not exist; the real
  method `googleAuthentication` is unrouted. And
  `SocialAuthService::googleAuthenticate` writes `name` +
  `is_otp_verified` columns that are not on the `users` table → it
  would throw on first use anyway. Decide: wire it up correctly or
  delete it.
* **[HIGH]** `Helper::deleteImage()` contains a stray `dd("jalis")` in
  its empty-input branch. Because the helper backs profile/group-avatar
  deletion, deleting an entity with a null image path **halts the whole
  request** with a debug dump. Remove it (root `CLAUDE.md` forbids
  leftover `dd()`).
* **[HIGH]** `ProfileController` (web, Settings) `UpdateProfile` assigns
  `$user->name`, but `users` has no `name` column → the save throws, is
  swallowed, and the endpoint silently never updates anything. Assign
  `first_name` / `last_name`.
* **[HIGH]** 5 `AdminGroupChatController` routes (`editMessage`,
  `addMembers`, `removeMember`, `makeAdmin`, `deleteMessages`) point at
  controller methods that don't exist. Implement or remove.
* **[HIGH]** `app/lib/features/chat/.../receiver_message_widget.dart`
  `_buildBlurPlaceholder` — the entire patent flow is duplicated
  verbatim across the `!isGroup` and `else` branches (~70 lines each),
  and each branch *still* re-checks `if (isGroup)` internally, leaving
  dead sub-branches. A fix to one copy won't reach the other — a
  maintenance trap directly on the load-bearing path. Collapse to a
  single code path that picks endpoint/target from `isGroup` once.
* **[HIGH]** Patent flow: if `mark-viewed` (`viewInboxImage` /
  `viewGroupFile`) returns `false`, the `.then` has no `else`/`catchError`
  — the blur never lifts, no error shows, the tap appears to do nothing.
  And if `recordVideoSilently()` returns `null` (no camera, permission
  denied, plugin throw — all swallowed) the media still unblurs but no
  reaction is ever sent, with no telemetry. Handle both failure paths:
  keep the placeholder retryable, surface an error, and report capture
  failures so the feature's failure rate is observable. Check
  `Permission.camera` / `Permission.microphone` before recording.
* **[HIGH]** Patent flow: `messageId!` / `userId!` / `groupId!` (all
  `int?`) are force-unwrapped in the placeholder tap handler. An
  optimistic or malformed realtime message with a null id throws an
  uncaught `TypeError` inside an async `.then`. Guard the handler —
  disable the tap when a required id is null.
* **[HIGH]** StreamBuilder error states are dropped across feature
  screens (`inbox_screen.dart` body + app-bar builders, others). The
  pattern is `waiting → spinner`, `hasData → content`, `else →
  SizedBox.shrink()` with no `hasError` branch — so a failed load
  renders a blank screen with no message and no retry. Add explicit
  `hasError` handling.
* **[MEDIUM]** `UserController::userDetais` returns HTTP **200** with
  `"User not found."` for a missing user — should be 404. The v1 chat
  controller has the same anti-pattern in `send` / `seenAll` / `room` /
  `markAsViewed` / `deleteChat` (soft failures return a 200 envelope or
  a `code:404` *in the body*). Clients cannot rely on HTTP status.
* **[MEDIUM]** `FirebaseTokenController::store` / `deleteToken` do
  `$x = FirebaseTokens::where(...)` then `if ($x)` — a query builder is
  always truthy, so the "delete if exists" always runs and
  `deleteToken`'s 404 branch is dead. Use `->exists()` / `->first()`.
* **[MEDIUM]** `ChatManageController::room()` resolves the user via the
  `api` guard while the rest of that controller uses the `web` guard —
  almost certainly a copy-paste slip.
* **[MEDIUM]** Flutter `rx_edit_profile/api.dart` maps the `bio`
  argument onto the backend form key `dob` — editing a bio likely
  writes the wrong field (and `dob` is not even a `users` column).
* **[MEDIUM]** `inbox_screen.dart` realtime callback hand-rolls a deep
  `Chat`/`Receiver`/`ReplyTo` construction from `json.decode` output
  with no null guards — a message from a deleted user or a malformed
  payload throws inside the Pusher callback. The models already have
  `fromJson`; reuse it and guard nested objects.
* **[MEDIUM]** `inbox_screen.dart` `cList` only populates
  `if (cList.isEmpty)`, so after the first load a re-fetch (after
  delete, after unblock) emits new server data that is discarded — the
  list only updates via local mutation or Pusher. `_deleteMessageDialog`
  calls `getInboxMessage` expecting a refresh that never reaches the
  UI. Reconcile new server data instead of gating on `isEmpty`.
* **[MEDIUM]** `AuthService::login` issues the JWT twice
  (`auth('api')->login($user)` then `tokenById($user->id)`); the first
  is wasted. Issue once.
* **[MEDIUM]** `AuthenticationController::resendRegisterOtp` validates
  `email` as `nullable` then builds the cache key
  `register_data_{$email}` — a null email collides on
  `register_data_`. Make `email` required.
* **[LOW]** 4 unrouted `Web\Backend` controllers are dead code (see
  `docs/testing/inventory.md` §8); `TermsAndPolicyController` is an
  empty stub. Remove or implement.
* **[LOW]** `ChnagePasswordApi` (Flutter) — class name is misspelled.
  Also `RECIEVE_TIMEOUT`, `Failure.resonseCode`, the `avater` widget
  param, and `waitingForSucess()` are misspelled public identifiers —
  fix in one rename pass.
* **[LOW]** Loosely-typed `should_show_blur` / `is_blurred` / `is_viewed`
  flags — the API sends `1`/`0`, bool, or string interchangeably and
  `GroupMessage` casts none of them. Pick one representation and cast
  consistently (this touches the patent blur flow — test carefully).
* **[LOW]** `EndPoints.resendOtp()` returns `/api/register` — a doubled
  `/api` segment *and* the wrong endpoint. It is unused; delete or fix.
* **[LOW]** `NetworkConstants.CONTENT_TYPE = "content-Type"` — wrong
  casing. The `APP_KEY` / `ACCEPT_LANGUAGE` constants and the
  `APP_KEY_VALUE` dart-define are defined but never sent as headers —
  either send them or delete the dead constants.

## 4. Database & data model

* **[HIGH]** The `users` migration declares `softDeletes()` and queries
  filter `whereNull('deleted_at')`, but the `User` model does **not**
  use the `SoftDeletes` trait. Consequence: `deleteProfile` hard-deletes
  the account, *and* every default `User` query includes soft-deleted
  rows (no global scope) — a "deleted" user still appears in chat /
  friend / search results. Add `use SoftDeletes` (or drop the column
  and the `whereNull` filters).
* **[HIGH]** `app/Models/TypingIndicator.php` backs a `typing_indicators`
  table that has **no migration** — any code path touching it throws
  "table not found". Add the migration or delete the model.
* **[HIGH]** Over-indexing on `chats` (migration
  `2025_07_28_045611`): the standalone `index('room_id')` and
  `index('receiver_id')` are prefixes of the composite indexes
  `['room_id','created_at']` / `['receiver_id','status']` — redundant
  dead weight that slows every write. Drop the single-column indexes.
* **[MEDIUM]** Reverse-direction lookup columns are unindexed:
  `users.status`, `users.role` (filtered by `AdminMiddleware`),
  `friends.friend_id`, `group_messages.reply_to_message_id`,
  `group_message_reads.user_id`. Add indexes where the query's leading
  column isn't already covered by a composite/unique index.
* **[MEDIUM]** `firebase_tokens` — `token` and `device_id` are
  `longText`; `device_id` is queried on every push fan-out and a
  `longText` can't be indexed efficiently. Make `device_id` an indexed
  `string`, `token` a `text`, and add a unique `(user_id, device_id)`
  constraint (`store()` already assumes one row per device).
* **[MEDIUM]** `notifications` table has **no migration**, so
  `NotificationController` (already noted as unrouted) could not work
  even if wired. The `app/Notifications/*` classes
  (`EventCreateNotification`, `PostCreateNotification`,
  `FollowNotification`, …) reference an events/posts/follow domain that
  does not exist in this messaging app — template leftovers. Delete the
  directory or add the migration + routes.
* **[MEDIUM]** Schema/model drift — `User::$fillable` lists
  `mobile_number`; the column is `phone`. The model casts a phantom
  `email_verified_at` that has no column, and omits boolean casts for
  `is_google_signin` / `is_apple_signin`. `GroupMessage::$casts` only
  has timestamps — add the `is_blurred` / `is_viewed` / `status` casts.
* **[MEDIUM]** `job_categories` and `c_m_s` tables (migrations
  `2025_07_19_*`) are referenced nowhere in `app/` — dead schema from a
  different project. Drop the migrations (and `PageEnum` / `SectionEnum`
  that go with the CMS).
* **[MEDIUM]** `Room` uniqueness — the unique index on
  `(user_one_id, user_two_id)` does not prevent a reversed-pair
  duplicate. Every room-creation path must normalise (min id in
  `user_one_id`) to match `scopeBetweenUsers`; verify `listCombined`'s
  `firstOrCreate` does so.
* **[LOW]** No DTOs / value objects — raw associative arrays pass
  between controllers and services. Typed objects would catch shape
  mistakes at the boundary.

## 5. API design & robustness

* **[HIGH]** `ChatService::conversation` uses `$perPage = 100000` —
  effectively "fetch the entire conversation unpaginated every time",
  then appends 4 computed accessors per row (each calling `auth()` /
  `request()`). Unbounded query + memory/latency bomb on long chats.
  Use real pagination (the v2 path does).
* **[MEDIUM]** Versioning is inconsistent: v1 chat is `auth/chat/*`, v2
  is `v2/auth/chat/*` (version segment in a different position), group
  chat is `auth/group/*` (no version), and `auth/group/mark-viewed/{id}`
  is not nested under `{group_id}` unlike its siblings. Pick one URL
  scheme.
* **[MEDIUM]** Response-envelope inconsistency: most endpoints use the
  `ApiResponse` trait, some build bespoke `response()->json()`;
  `listGroups` returns groups under a top-level `groups` key instead of
  `data`. Worse, the trait keys success as `success` but failure as
  `status`. Standardise one envelope and the 422 body shape.
* **[MEDIUM]** Validation is inline (`Validator::make` /
  `$request->validate`) in every controller. Migrate to Form Requests
  and standardise the 422 body in the same pass (kept inline by the
  refactor only because Form Requests change the 422 shape).
* **[MEDIUM]** No API documentation — no OpenAPI/Swagger spec, no
  Postman collection — despite `routes/api.php` being the documented
  contract for a separate client team. Generate/commit one under
  `docs/`.
* **[LOW]** Route param naming is contradictory
  (`{reported_user_id}` vs `{block_user_id}` vs `{user}` vs `{id}`;
  `$group_id` vs `$groupId`). Normalise.
* **[LOW]** `routes/api.php` has `// working` / `// wroking` noise
  comments on nearly every line — the test suite is the source of truth
  now. Remove.

## 6. Backend architecture & code quality

* **[HIGH]** v1 `ChatController` (`auth/chat/*`) and v2
  `SingleChatController` (`v2/auth/chat/*`) are near-duplicate chat
  implementations. Two code paths for one feature is a maintenance trap
  and a patent-flow risk. Pick one, migrate clients, retire the other.
* **[MEDIUM]** The extracted service classes are large
  (`SingleChatService` ~1000 lines). The CP1-6 refactor was a
  mechanical extraction, not a decomposition — break the big services
  into cohesive units; methods are still long and multi-purpose.
* **[MEDIUM]** Services reach directly for facades (`Cache`, `Mail`,
  `DB`, `Auth`, `Storage`), making isolated unit testing hard. Inject
  collaborators (or wrap them).
* **[MEDIUM]** `Chat::$appends` adds 4 viewer-relative accessors
  (`humanize_date`, `short_text`, `type`, `media_type`) to *every*
  serialized row; `getTypeAttribute` / `isMine` call `auth()` /
  `request()` per row. Combined with the unpaginated `conversation`
  query that is tens of thousands of `auth()` lookups per request. Move
  viewer-relative fields into an API Resource that resolves the viewer
  once.
* **[MEDIUM]** `User::allFriends()` runs a `pluck` query *inside* the
  relationship definition — an N+1 generator that cannot be
  eager-loaded. Replace with a query scope. `Room::lastMessage()` should
  use `latestOfMany()` so chat-list rendering doesn't N+1.
* **[MEDIUM]** Cashier is pulled in (`Billable` on `User`,
  `config/cashier.php`, the `stripe-webhook` CSRF exception) but billing
  is entirely unrouted — dead surface area + an extra dependency. Either
  finish billing or remove Cashier. Same for Reverb config when the
  deployment uses Pusher.
* **[LOW]** Eloquent queries are built inline in service methods —
  common ones (friend-id gathering, unread scopes) should be model
  scopes / query objects.
* **[LOW]** Dead commented-out code and emoji comments (`✅ FIXED`,
  trailing `//hello` in `bootstrap/app.php`) throughout controllers and
  services. Sweep.

## 7. App architecture & code quality

* **[HIGH]** Five overlapping state/DI/navigation mechanisms — GetX
  (`GetMaterialApp`, `.tr`, navigation), `provider` (`MultiProvider`),
  `rxdart` `BehaviorSubject` (the `rx_*` registry), `get_it` (DI), and
  raw `setState` + `StreamBuilder` in screens. There is no consistent
  layer separation; business logic lives directly in `StatefulWidget`s
  (`inbox_screen.dart` reconciles messages, manages Pusher, builds
  models). The global mutable `rx_*` singletons in `api_access.dart` are
  effectively unscoped global state. Pick one paradigm (GetX is already
  the root) and migrate logic into controllers/viewmodels.
* **[HIGH]** No offline handling. `DataSource.NO_INTERNET_CONNECTION` /
  `CACHE_ERROR` are defined but `_handleError` never maps any
  `DioExceptionType` to them. There is no connectivity package, no
  offline banner, no cached-message fallback — offline, every screen
  shows an infinite spinner. Add connectivity detection and an offline
  state. (The abandoned `initInternetChecker` in `helpers_method.dart`
  shows this was started.)
* **[HIGH]** `appData.read(kKeyAccessToken)` is read into a
  non-nullable `String` with no null check in `loading.dart`,
  `inbox_screen.dart`, `dio.dart`. A half-initialised session
  (`isLoggedIn=true`, token missing) throws a `TypeError` that takes
  down the splash/inbox with no recovery. Null-check and route to
  login.
* **[MEDIUM]** `inbox_screen.dart` `_messageController.addListener`
  calls `setState(() {})` on every keystroke — rebuilds the whole
  screen including the `ListView` and every bubble per character. Scope
  the rebuild to the composer (`ValueListenableBuilder`).
* **[MEDIUM]** `waitingForSucess()` in `loading_helper.dart` pushes a
  dialog using the global `NavigationService.context` and pops it in
  `finally` with no reference to the specific route — overlapping API
  calls pop the wrong route. `waitingForSucessWithoutIndicator()` is a
  byte-identical copy that still shows a spinner (its own doc admits
  it). Capture and pop the specific dialog route; fix or delete the
  "without indicator" variant.
* **[MEDIUM]** `receiver_message_widget.dart` has
  `// ignore_for_file: must_be_immutable` and a mutable public
  `bool isBlurred` field on a `StatefulWidget` — a Flutter anti-pattern.
  State already mirrors it into `_isBlurred` and re-syncs in
  `didUpdateWidget`, so the mutable field is redundant and wrong. Make
  it `final`, drive blur through state, remove the ignore.
* **[MEDIUM]** Dio `connectTimeout` and `receiveTimeout` are both
  `Duration(minutes: 10)` — a dead connection leaves the user on a
  spinner for ten minutes. Use 15-30s connect; a bounded larger
  receive timeout for uploads only.
* **[MEDIUM]** `inbox_screen.dart` `_jumpToMessage` falls back to
  `index * 150.0` — a hardcoded guessed row height that lands wrong for
  images / reactions / multi-line text. Rely on the `GlobalKey` /
  `ensureVisible` path.
* **[MEDIUM]** `main.dart` root `PopScope(canPop: false)` with an empty
  handler swallows the OS back gesture app-wide with no effect.
  Implement the intended confirm dialog or remove it.
* **[MEDIUM]** `main.dart` wraps the child in
  `MediaQuery(data: MediaQuery.of(context), …)` — a no-op layer.
  Remove (or restore the intended text-scale clamping).
* **[MEDIUM]** `setInitValue()` has a hardcoded 3-second
  `Future.delayed` that blocks every cold start purely to pace the
  splash. Show the splash only as long as real init takes.
* **[LOW]** Debug statements left in: `log("Is blur …")` inside
  `receiver_message_widget.dart` `build()` (logs every rebuild), full
  message-payload logs in the inbox `connect()` callback, `print("Dio
  update")` in `dio.dart`. Remove.
* **[LOW]** Two conflicting FCM background handlers registered — a
  no-op `backgroundHandler` in `main.dart` and `handleBackgroundMessage`
  in `notification_services.dart`. Keep one.
* **[LOW]** `getHttp` accepts a `data` parameter it documents as
  ignored — invites misuse. Remove it.
* **[LOW]** `inbox_screen.dart` `dispose()` calls `cList.clear()` on a
  field about to be GC'd — pointless and signals ownership confusion.
  Remove.

## 8. Performance

* **[HIGH]** `inbox_screen.dart` (and likely `group_inbox_screen.dart`)
  use `ListView.builder` with **both** `Expanded` and
  `shrinkWrap: true` — `shrinkWrap` forces every message widget (each
  with a video controller / blur stack) to build up front, defeating
  lazy building. Drop `shrinkWrap: true`; the `Expanded` already bounds
  it.
* **[MEDIUM]** Pusher broadcasts and the Firebase push fan-out run
  synchronously inside the request (`send`, `sendMessage`,
  `forwardMessage`) — a slow FCM call delays the user's response. Move
  push delivery to queued jobs.
* **[MEDIUM]** Mail is sent synchronously (`Mail::to()->send()` in the
  OTP / verification flows). Queue it (`ShouldQueue`).
* **[MEDIUM]** `NotificationController::allNotifications` does `->get()`
  with no limit — unbounded result set. Paginate.
* **[MEDIUM]** `_messageKeys` (a `GlobalKey` per message id) is never
  pruned, and `VideoControllerCache` (a process-wide static map) is
  never `clear()`ed — its dispose call is commented out in
  `inbox_screen.dart`, so video controllers from every conversation
  accumulate for the whole app session. Prune `_messageKeys` with the
  list; clear/scope the video cache when leaving chat.
* **[LOW]** `listCombined` calls `Room::firstOrCreate` per user — a
  write during a read and a potential N+1. Review.
* **[LOW]** No caching strategy beyond the registration/OTP cache — hot
  read endpoints (chat list, profile) could benefit.

## 9. UX, accessibility & internationalization

* **[MEDIUM]** No localization. `pubspec.yaml` has no
  `flutter_localizations` / `intl` ARB setup; every UI string is
  hardcoded English. Yet `NetworkConstants.ACCEPT_LANGUAGE_VALUE = "pt"`
  tells the backend the user wants Portuguese, and `data_source.dart`
  runs error messages through GetX `.tr` with no translation maps
  registered (so `.tr` is a no-op). Commit to one language or add real
  localization, and align the `Accept-Language` header.
* **[MEDIUM]** No accessibility — no `Semantics` labels anywhere. The
  consequential blur-placeholder tap (which records the user) announces
  nothing to a screen reader; avatars and icon buttons are unlabelled.
  Add `Semantics`, especially on the blur placeholder.
* **[MEDIUM]** No loading/empty/error states on most screens beyond a
  bare spinner — see the dropped StreamBuilder error branches in §3.
  Design proper empty and error states with retry.
* **[MEDIUM]** Single hardcoded dark theme — `main.dart` defines one
  `ThemeData`, no `darkTheme`, no `themeMode`, and colour literals
  (`Color(0xFF1A1E0A)`, `Colors.white30/54/70`) are scattered in
  widgets instead of theme tokens. Move literals into the theme; decide
  whether to support light mode.
* **[LOW]** `useMaterial3: false` opts the app out of Material 3 and
  onto the legacy/deprecated component behaviour. Plan an M3 migration.

## 10. Testing

* **[HIGH]** No widget test for `InboxScreen` / `GroupInboxScreen` — the
  screens that host the patent flow. The patent flow's *integration*
  (tap placeholder → mark-viewed → record → upload → optimistic insert
  → reconcile, including the Pusher event path) is only covered in
  isolation with fakes; nothing exercises the full loop through the
  screen. `CLAUDE.md` mandates an end-to-end regression test for
  exactly this loop. There is also no test for the `mark-viewed` /
  recording **failure** paths (see §3).
* **[MEDIUM]** Backend tests are HTTP feature tests only — the extracted
  services have no isolated unit tests. Add them now that logic is in
  services.
* **[MEDIUM]** No tests for `ChatRealtimeService`, `VideoControllerCache`
  (LRU eviction order/dispose), `NotificationService`, or the auth
  screens (login/signup/OTP UI + input validation feedback).
* **[MEDIUM]** No static analysis on the backend — add PHPStan /
  Larastan to CI.
* **[MEDIUM]** No coverage threshold — CI runs coverage but never fails
  below a floor. Set one and ratchet it up (both backend and app).

## 11. CI/CD, tooling & dependencies

* **[HIGH]** No security scanning — no `.github/dependabot.yml`, no
  CodeQL, no dependency audit. Add Dependabot for `composer` / `pub` /
  `npm` / `github-actions`, a `composer audit` step to `backend-ci.yml`,
  and optionally CodeQL.
* **[HIGH]** `backend-ci.yml` runs `composer update` instead of
  `composer install` — CI does not test the locked versions a developer
  or production gets, and the cache key hashes `composer.json` (never
  changes when only `composer.lock` does) so it can serve stale
  `vendor/`. Once `composer.json` is trusted (see §1), switch to
  `composer install`, key the cache on `composer.lock`, and run
  `composer validate --strict`.
* **[HIGH]** No native build verification — `flutter-ci.yml` omits both
  iOS and Android builds, so a change that breaks compilation
  (including on the camera/recording path) still merges. Re-enable at
  least `flutter build apk --debug`; track the iOS plugin-compat issue
  as a real ticket.
* **[MEDIUM]** `backend-ci.yml` never builds the Vite/Tailwind admin
  frontend (`backend/package.json` defines `vite build`) — a broken
  Blade/Vite asset would not be caught. Add an `npm ci && npm run build`
  job.
* **[MEDIUM]** `deploy-dashboard.yml` triggers on push to the stale
  `feature/test-environment` branch (97 commits behind `develop`) — the
  live dashboard effectively never refreshes. Point it at `develop`.
* **[MEDIUM]** `APP_DEBUG=true`, `APP_ENV=local`, `LOG_LEVEL=debug` ship
  in `backend/.env.example`. If the production `.env` was derived from
  it, every exception returns a full Ignition stack trace (DB
  credentials, env) to the client. Set the example to production-safe
  values and add a deployment checklist.
* **[MEDIUM]** No documented list of *required* vs optional env vars.
  `.env.example` has ~40 keys with no distinction; the mobile side
  needs `BASE_URL` + `APP_KEY_VALUE` dart-defines with no `.example`
  analog. Add a `docs/configuration.md` (or README table).
* **[MEDIUM]** Branch-protection path filters mean a backend-only or
  app-only PR leaves one required check unreported, forcing `--admin`
  merges. Make both checks always report (a no-op success job) so
  protection works without admin override.
* **[MEDIUM]** No static-analysis / format gate on either side — `pint`
  is not an enforced CI check (PHP) and `dart format` is disabled in
  `flutter-ci.yml` (Dart). Gate both; formatting drifts otherwise.
* **[LOW]** `backend/package.json` depends on `reverb: ^0.2.0` as a
  runtime dependency — almost certainly a wrong/unmaintained package
  (a Reverb client uses `laravel-echo` + `pusher-js`, both already
  listed). Verify it is imported anywhere; if not, remove it.
* **[LOW]** Flutter app has dead/overlapping dependencies —
  `flutter_displaymode` (only use is commented out), `chewie` (not
  referenced in `lib/`; `flick_video_player` is the one used), and the
  `provider` package alongside GetX. `dev_dependencies` already includes
  `dependency_validator` — wire `dart run dependency_validator` into CI
  and prune what it flags.
* **[LOW]** `pubspec.yaml` Dart SDK floor `^3.7.2` is far below what CI
  / the lockfile pin (Dart >= 3.11) — misleading for local setup. Raise
  the floor to match.
* **[LOW]** `composer.json` `require-dev` keeps `laravel/breeze`
  (post-setup scaffolding) and `laravel/sail` — confirm intentional,
  else remove the scaffolding bloat.

## 12. Repository hygiene & documentation

* **[HIGH]** Firebase config files are committed:
  `app/android/app/google-services.json`,
  `app/ios/Runner/GoogleService-Info.plist`, and the generated
  `app/lib/firebase_options.dart` — all carrying live Firebase API keys
  and project ids. The root `.gitignore` ignores `service-account*.json`
  / `*.keystore` but not these. Firebase client config is semi-public
  (it ships in the binary), but committing it pins the repo to one
  Firebase project with no dev/prod separation. Decide explicitly:
  accept-and-document, or `.gitignore` them + provide `.example`
  templates + a FlutterFire-configure step. Either way, restrict the
  Firebase API keys by app package / bundle id in the Google Cloud
  console.
* **[MEDIUM]** No release process. `develop` is 97 commits ahead of
  `main` (which "mirrors production") with no commits back and **no git
  tags at all**; `app/pubspec.yaml` is `1.0.9+10` but no build maps to a
  commit. Establish a cadence: merge `develop`→`main`, tag releases
  (`v1.0.9`), add a `CHANGELOG.md`.
* **[MEDIUM]** `app/README.md` is the unmodified Flutter template
  ("A new Flutter project"). `backend/README.md` is inaccurate (says
  Sanctum — the app uses `tymon/jwt-auth`; placeholder clone URL; omits
  `jwt:secret` and the `APP_KEY_VALUE` gate; ` ```base ` fences).
  Rewrite both.
* **[MEDIUM]** No `LICENSE` file (despite `composer.json` declaring
  `"license": "proprietary"` — important for a patent-protected
  product), no `CONTRIBUTING.md`, no current architecture doc. Add a
  proprietary `LICENSE`, a `CONTRIBUTING.md` consolidating the
  branch/commit/test rules, and `docs/architecture.md` (data model,
  broadcast channels, reaction-message lifecycle).
* **[LOW]** `app/ios/File.txt` is a stray committed file containing only
  `495630`. Delete it.
* **[LOW]** ~40 stale `refactor/*` / `test/*` / `docs/*` remote branches
  whose work is already merged. Delete merged branches (or enable
  GitHub "automatically delete head branches").
* **[LOW]** Android release build uses the **debug** signing config
  (`app/android/app/build.gradle.kts`). Wire a real release signing
  config reading from a git-ignored `key.properties` before any Android
  store release; document the signing setup.
* **[LOW]** No build flavors / environments. `endpoints.dart` defaults
  to a hardcoded production URL (the `String.fromEnvironment` form is
  commented out) and there is one Firebase project for all builds — a
  debug build talks to prod API + prod Pusher. Add dev/staging/prod
  flavors with separate app ids and Firebase projects; make the base URL
  `String.fromEnvironment` with a safe default.
* **[LOW]** Incomplete project rename — the Flutter package is still
  `achiar_expert_app` and the Kotlin source path is still
  `com/example/achiar_expert_app` while the applicationId is the correct
  `com.reacti.app`. Finish the rename.

## 13. Dead code & files to delete

Consolidated delete list (cross-referenced above):

* `backend/routes/web.php` maintenance routes (§1) — **delete now**,
  security risk.
* `App\Services\ChatFileService` — orphaned file-upload service nothing
  references (note: it stores to the `public` disk while
  `SingleChatService` uses `s3`, so adopting it instead is a
  *functionality* change). Adopt everywhere or delete.
* `app/Notifications/*` + the unrouted `NotificationController` —
  template leftovers for a non-existent domain (§4).
* `job_categories` / `c_m_s` migrations, `PageEnum`, `SectionEnum` —
  dead CMS schema (§4).
* `TypingIndicator` model — no backing table (§4).
* 4 unrouted `Web\Backend` controllers + `TermsAndPolicyController`
  stub (§3).
* `app/lib/.../video_view_screen.dart` — the **entire file** is
  commented out (~170 lines). Delete it; git history preserves it.
* ~85-line commented "quoted original message" block in
  `receiver_message_widget.dart`; commented `initInternetChecker` in
  `helpers_method.dart`; commented `rx_*` instances in `api_access.dart`;
  commented social-login routes in `web.php`.
* `app/ios/File.txt` (§12).
* Unused dependencies — `flutter_displaymode`, `chewie`,
  `reverb` (npm), possibly `provider`, Cashier/Reverb (backend) (§11,
  §6).

## 14. Notes for whoever picks this up

* The CP1-6 refactor (`docs/refactor/backend-refactor-plan.md`) put all
  API business logic into `app/Services/*`. Fix bugs in the service
  now, not the controller.
* The frontend refactor (`docs/refactor/frontend-refactor-plan.md`) made
  the `rx_*` data sources constructor-injectable and extracted the chat
  sub-widgets; a widget-test harness exists at
  `app/test/support/widget_harness.dart` (`pumpInApp`).
* Pre-existing behaviour — including every bug above — is pinned by the
  test suite. Fixing a bug will (correctly) break the test that pinned
  the old behaviour; update that test in the same PR.
* The patent flow (silent front-camera recording on `mark-viewed`) is
  load-bearing — see root `CLAUDE.md`. Re-run the patent suites after
  any change near `send` / `markAsViewed` / the blur flags. The privacy
  item in §2 must be resolved *with product and legal*, not unilaterally.
* Suggested order of attack: §1 CRITICALs (web.php routes, rate
  limiting, OTP-in-response, TLS override, token storage) and §2 first
  — they are exploitable today — then the §3 HIGH correctness bugs,
  then the structural work in §4-§7.
