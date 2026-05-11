# Test inventory — baseline for the testing initiative

This document is the starting point of the project-wide testing buildout. It
records exactly what tests exist today, what they cover, and what is *not*
covered yet. It is intentionally factual — no aspirations, no plans. The plan
lives in the conversation/PR that introduces this file; subsequent phases will
chip away at the gaps recorded here.

Snapshot date: **2026-05-09** (initial), updated **2026-05-10** with Phase
2-4 progress — see Section 8.
Branch: `feature/test-environment`

---

## 1. Existing tests — backend (`backend/tests/`)

| File | Layer | Status | What it asserts |
|------|-------|--------|------|
| `Unit/ExampleTest.php` | placeholder | keep until first real unit test lands, then delete | `1 + 1 == 2`. Pure scaffolding from `laravel/breeze`. |
| `Feature/Auth/LoginTest.php` | feature | real | `POST /api/login` returns 200 + token on valid creds; returns 401 + `"Invalid password."` on wrong password. |
| `Feature/Friends/FriendRequestTest.php` | feature | real | `POST /api/friends/send-request` creates a `friend_requests` row. |
| `Feature/Patent/ReactionFlowTest.php` | feature (regression) | **load-bearing** — the patent flow | End-to-end: send media → mark-viewed flips `is_blurred`/`is_viewed` → reaction upload chains back via `reply_to_id`. Storage is faked. |
| `TestCase.php` | base class | empty stub | Inherits from Laravel's `TestCase`; no shared setup yet. |

**Configuration**: `backend/phpunit.xml` defines two suites (`Unit`, `Feature`),
runs against an in-memory SQLite DB, fakes broadcast/cache/queue/mail, and
hard-codes a CI placeholder `APP_KEY` and `JWT_SECRET`.

## 2. Existing tests — app (`app/test/`)

| File | Layer | Status | What it asserts |
|------|-------|--------|------|
| `widget_test.dart` | placeholder | keep until first real widget test lands, then delete | `1 + 1 == 2`. Explicit comment notes that mounting `MyApp` would require Firebase/GetStorage/DI mocks. |
| `networks/endpoints_test.dart` | unit | real | 8 assertions locking the URL strings the client expects from `EndPoints` (login, signup, profile, send-message, mark-viewed, group mark-viewed, conversation, group send). The patent-flow URLs are explicitly called out. |

`app/integration_test/` does **not exist** yet — no on-device or driver tests.

## 3. Surface area — what *could* be tested

### Backend

| Bucket | Count | Tested today |
|--------|------:|-------------:|
| Routes in `routes/api.php` | ~80 | 3 |
| API controllers (`app/Http/Controllers/Api/**`) | 18 (+1 stray `Group/test.php` to delete) | 3 |
| Web/admin controllers (`app/Http/Controllers/Web/**`) | 21 | 0 |
| Broadcast events (`app/Events/**`) | 9 | 0 |
| Eloquent models (`app/Models/**`) | 17 | 0 |
| Services (`app/Services/**`) | 2 | 0 |
| Jobs (`app/Jobs/**`) | 0 (directory absent) | n/a |
| Model factories (`database/factories/**`) | 1 (`UserFactory`) | — |

### App

| Bucket | Count | Tested today |
|--------|------:|-------------:|
| Screens (`*_screen.dart` under `lib/features/**`) | 32 | 0 |
| `rx_*` data sources (one folder per remote op) | 37 | 0 |
| Chat-feature widgets (incl. patent file) | 5 | 0 |
| Network plumbing (`lib/networks/**`) | 8 files | 1 (`endpoints.dart`) |
| Total Dart source files under `lib/` | 173 | 1 |

## 4. Coverage of the patent flow specifically

The patent flow is the only thing CLAUDE.md flags as "do not break". Today's
coverage of it:

| Step in the loop | Covered by |
|------------------|------------|
| Sender sends media → server stores `message_type=normal`, `is_blurred=true` | `ReactionFlowTest::it_locks_the_full_patent_flow` |
| `mark-viewed` → server flips `is_blurred=false`, `is_viewed=true` | same test |
| Receiver uploads `type=reaction` w/ `reply_to_id` → server chains it | same test |
| Pusher event broadcasts on send / mark-viewed | **not covered** |
| Client: `recordVideoSilently()` actually fires after `mark-viewed` succeeds | **not covered** (no widget test for `receiver_message_widget.dart`) |
| Client: URLs the patent flow uses haven't moved | `endpoints_test.dart` |

So the *server-side* loop is locked. The *client-side* trigger and the
*broadcast* leg are not.

## 5. Run status

| Suite | Last result | Where verified |
|-------|-------------|----------------|
| Backend (`php artisan test`) | green | GitHub Actions run `25606621562` (31s) on `62fd176` |
| App (`flutter test`) | green | GitHub Actions run `25606621558` (1m27s) on `62fd176` |

Local execution on the maintainer's Windows box: **not possible right now** —
neither `php` nor `flutter`/`dart` is on `PATH`. CI is the only place tests
actually run today. Closing this gap is a Phase-5 prerequisite (pre-push hooks
need a local toolchain).

## 6. Concrete gaps to close (input for Phase 2 onwards)

These are the things later phases will touch. Listed for traceability, not
prioritised here — priorities live in the plan.

- **No coverage measurement.** `phpunit.xml` declares a `<source>` block, but
  CI runs with `coverage: none` and there is no Dart `--coverage` invocation.
  Phase 2 turns these on and uploads the artifacts.
- **No factories beyond `User`.** Anything wanting to assert against `Chat`,
  `Group`, `FriendRequest`, etc. has to hand-build rows. Phase 3 adds the
  missing factories before adding tests against those models.
- **No event/broadcast tests.** All 9 `App\Events\*` classes are uncovered.
  Phase 3 closes this with `Event::fake()` assertions piggybacking on the
  feature tests.
- **No widget tests.** `app/test/` contains zero `testWidgets(...)` calls. The
  patent-flow widget (`receiver_message_widget.dart`) is the highest priority.
- **No integration tests.** `app/integration_test/` is missing entirely.
- **One stray non-controller file** in `backend/app/Http/Controllers/Api/Chat/Group/test.php`.
  Likely dead. Confirm and delete during Phase 3.
- **No pre-push hook.** Phase 5 adds Lefthook; blocked on getting PHP/Flutter
  installed locally.
- **Web/admin controllers (21 files)** are entirely untested. They serve the
  Laravel admin UI, not the mobile client, so they sit lower in the priority
  order than API controllers — but they are in scope eventually.

## 7. Audit finding (added 2026-05-10): events declared vs. dispatched

While building Phase 3 it became clear the "9 broadcast events" line in
Section 3 overstated real coverage *surface*: most of the nine classes
were declared but never fired. Phase 3.5 / Phase 3.6 closed the gap.

| Event class | Declared | Dispatched in code |
|-------------|---------:|-------------------:|
| `App\Events\MessageSendEvent` | yes | yes — `ChatController::send`, `V2\SingleChatController::send/forward` |
| `App\Events\GroupMessageSendEvent` | yes | yes — `GroupMessageController::sendMessage` |
| `App\Events\Chat\V2\UserTypingEvent` | yes | yes — `V2\SingleChatController` typing |
| `App\Events\MessageReadEvent` | yes | yes — `ChatController::markAsViewed` (Phase 3.5) |
| `App\Events\MessageReactionEvent` | yes | yes — `ChatController::send` for `message_type=reaction` (Phase 3.6) |
| `App\Events\MessageDeletedEvent` | yes | yes — `ChatController::deleteMessage` (Phase 3.6) |
| `App\Events\GroupUpdatedEvent` | yes | yes — `GroupCreateController::updateGroup` + `updateAvatar` (Phase 3.6) |
| `App\Events\UserOnlineEvent` | yes | yes — `AuthenticationController::login` + `logout` (Phase 3.6) |
| ~~`App\Events\TypingEvent`~~ | **deleted** | superseded by `Chat\V2\UserTypingEvent`; removed in Phase 3.6 |

All declared-and-kept events are now fired somewhere. Each one has a
feature test under `tests/Feature/Events/` asserting the dispatch with
the expected payload.

## 8. Phase progress (running log)

### Phase 1 — inventory (complete, commit `d39ea13`)
This document.

### Phase 2 — coverage tooling (complete, commit `c9d4751`)
* Backend CI: switched from `coverage: none` to `coverage: pcov`
  (faster than xdebug for coverage-only). Tests now emit
  `backend/coverage/clover.xml`, uploaded as artifact `backend-coverage`.
* App CI: `flutter test --coverage` emits `app/coverage/lcov.info`,
  uploaded as artifact `app-coverage`.
* No threshold gating yet (intentional — see commit body).

### Phase 3 — factories + events (complete, commit `cf03536`)
* New factories: `ChatFactory`, `RoomFactory`, `FriendRequestFactory`,
  `GroupFactory`, `GroupMemberFactory`, `GroupMessageFactory`. The
  `ChatFactory` ships `blurredMedia()`, `viewed()`, and
  `reactionTo($original)` states tailored to the patent flow.
* New event test: `tests/Feature/Events/PatentFlowEventsTest.php`
  asserts `MessageSendEvent` dispatches twice in the patent flow
  (normal media send + reaction send-back) with the expected payload.
* Removed dead code: `backend/app/Http/Controllers/Api/Chat/Group/test.php`
  (bare PHP fragment, never autoloaded).

### Phase 3.5 — wire MessageReadEvent on mark-viewed (in flight)
* `ChatController::markAsViewed` now broadcasts `MessageReadEvent($room_id,
  $user_id)` after flipping `is_viewed`/`is_blurred`. This lets the sender's
  client swap "sent" → "viewed" in the patent flow without polling.
* `PatentFlowEventsTest` extended to fake `MessageReadEvent` and assert it
  dispatches once, with the right room id and viewer id, between the two
  send legs. The test now covers all three realtime legs of the loop.
* `seenAll`/`seenSingle` in the same controller mark messages as read
  but do *not* yet broadcast — separate from the patent flow's
  mark-viewed semantics. Track as a follow-up if read receipts in the
  conversation list need realtime updates.

### Phase 3.6 — wire (or delete) the rest of the dead events
* `MessageDeletedEvent` — fires from `ChatController::deleteMessage`
  with the chat id, room id, and `deleteType: 'for_everyone'`. The
  controller now fetches the chat row first so `room_id` is available
  before the soft-delete.
* `MessageReactionEvent` — fires from `ChatController::send` whenever a
  `message_type=reaction` chat is created. Carries the reaction
  message id, room, reactor user id, file URL, and the running count
  of reactions on the parent message (computed via `reply_to_id`).
* `GroupUpdatedEvent` — fires from `GroupCreateController::updateGroup`
  (`updateType: 'info'`) and `updateAvatar` (`updateType: 'avatar'`).
  Carries the updated fields and the admin who made the change.
* `UserOnlineEvent` — fires from `AuthenticationController::login`
  with `isOnline: true` and from `logout` with `isOnline: false` (the
  logout broadcast happens *before* `auth('api')->logout()` so the
  user reference is still valid).
* `TypingEvent` — **deleted**. Superseded by
  `App\Events\Chat\V2\UserTypingEvent`, which is the one actually
  used by `V2\SingleChatController::typingStatus`.
* New tests under `tests/Feature/Events/`:
  `MessageDeletedEventTest`, `UserPresenceEventsTest`,
  `GroupUpdatedEventTest`. `PatentFlowEventsTest` extended to also
  assert `MessageReactionEvent` on the reaction send leg.

### Phase 4 — patent-flow widget render-state test (complete, commit `8da65ae`)
* New test: `app/test/features/chat/widget/receiver_message_widget_test.dart`
  locks four visual contracts of `ReceiverMessageWidget` — plain text,
  blur placeholder, reaction bubble, `didUpdateWidget` blur sync.
* **Gap (intentional, tracked as follow-up):** the interactive trigger
  (tap blur → mark-viewed → silent reaction record → upload) is not
  covered. Locking it requires either a refactor of
  `receiver_message_widget.dart` to accept its rx_* dependencies and
  `recordVideoSilently()` via constructor (proper DI), or an
  `integration_test/` test that fakes the camera platform channel and
  the HTTP server. Pick one before claiming the patent flow is fully
  locked at the client layer.

### Phase 5 — pre-push hook (not started)
Still blocked on getting `php` and `flutter`/`dart` on the maintainer's
local `PATH`. Lefthook config is the easy part once the toolchain is
present.

### Regression-net buildout (2026-05-11)

User asked to test "everything, prioritized by importance" before
starting any code changes, so a refactor on a new branch can be
verified against the baseline. Driven through the agreed tiers
sequentially, happy + auth + validation depth.

**Test counts at this point:**
- Backend: 198 passing (377 assertions). 0 warnings since the dotenv
  file is now seeded in CI (commit `7a17519`).
- App: 46 passing.

**Coverage added by tier:**

* **Prereqs** — `--display-warnings` (`9ed65db`) found that every
  feature test was reporting a `file_get_contents(…/backend/.env)` PHP
  warning. Fixed by `touch .env` in CI (`7a17519`). Warning count went
  from 12 to 0.
* **Tier 1 — Patent flow gaps**
  - `Patent\GroupReactionFlowTest` — the 3-leg group patent loop
    (send → mark-viewed → reaction) with per-user blur-status
    assertions.
  - Client trigger (interactive: tap → record → upload) **still not
    covered** — needs constructor-injected DI on
    `receiver_message_widget.dart` or an `integration_test/` flutter
    test with a faked camera platform channel.
* **Tier 2 — All API endpoints** (happy + auth + validation):
  - Auth: `RegistrationTest`, `PasswordResetTest`.
  - Profile: `UserProfileTest`.
  - Friends: `FriendRequestEndpointsTest`, `FriendsTest`.
  - Moderation: `ReportUserTest`, `UserBlockTest`.
  - Chat v1: `Chat\ChatControllerTest` (list, conversation, room,
    search, seen-all, seen-single, delete-chat, plus auth/validation
    on the patent-flow endpoints).
  - Group: `Group\GroupCreateControllerTest`,
    `Group\GroupManageMemberTest`, `Group\GroupMessageControllerTest`.
  - Firebase: `Firebase\FirebaseTokenTest`.
  - Privacy: `Privacy\PrivacyTest`.
  - User listing: `User\UserListingTest`.
  - `FindFriendController::findContacts` **skipped** — references a
    `blocked_users` table that doesn't exist in the migration set
    (UserBlock uses `user_blocks`); endpoint will throw at SQL level
    before a test can assert anything. Likely a bug in the controller.
  - `SocialLoginController` **skipped** — third-party OAuth deps make
    it impractical without a fake provider; revisit if social signin
    becomes load-bearing.
  - V2 `SingleChatController` **skipped** — duplicates v1 behavior and
    is not on the patent-flow path; revisit if the app migrates fully.
* **Tier 3 — Model unit tests**:
  - `Unit\Models\ChatTest` — scopes (`betweenUsers`, `forRoom`,
    `unreadFor`), state helpers (`markAsRead`, `markAsDelivered`,
    `hasMedia`, `isReply`, `isForwarded`), media_type / short_text
    accessors.
  - `Unit\Models\RoomTest` — `hasUser`, `getOtherUser`,
    `scopeForUser`, `scopeBetweenUsers`, `unreadCountFor`.
  - `Unit\Models\GroupTest` — `isMember` / `isAdmin` / `isOwner`,
    `admins()` relation filter.
* **Tier 4 — Client side, partial**:
  - `app/test/networks/endpoints_test.dart` expanded from 8 to 35
    assertions — every `EndPoints` URL the client uses is now pinned,
    and the backend side of each is asserted by a Tier-2 PHP test.
    A rename breaks both sides simultaneously.
  - rx_* data-source tests **not added** — would need a Dio
    MockAdapter or a constructor-injection seam on the singleton api
    classes. Tracked as follow-up.
* **Tier 5 — Web/admin controllers** — **not done**. 21 admin
  controllers serve the Laravel admin UI, not the mobile app, so they
  sit lowest in the priority order. Pick up if the admin UI becomes
  load-bearing.

### Open follow-ups (carried across phases)

* **Patent-flow client trigger** — refactor
  `receiver_message_widget.dart` for constructor-injected
  dependencies, or add an `integration_test/` test that fakes the
  camera platform channel. Server-side ReactionFlowTest +
  GroupReactionFlowTest + PatentFlowEventsTest cover the loop on the
  backend; the visual contracts on the client are covered by
  `receiver_message_widget_test.dart`. The interactive trigger
  (`viewInboxImageRx.viewInboxImage()` → `recordVideoSilently()` →
  `sendMessageRx.sendMessage(type: "reaction")`) is the missing piece.
* **rx_* / api data sources on the client** — singletons like
  `SendMessageRx`, `ViewInboxImageRx` access HTTP via a top-level
  `postHttp(...)` function. Tests need either a Dio MockAdapter
  registered in `dio/dio.dart` for test mode, or a refactor to
  constructor-inject the api singletons. Either choice lets us write
  one rx_* test per data source and complete Tier 4.
* **`seenAll` / `seenSingle`** in `ChatController` mark messages as
  read but do not broadcast. Different semantics from `mark-viewed`
  (the patent-flow blur trigger). If realtime read receipts in the
  conversation list become a product requirement, dispatch
  `MessageReadEvent` from those endpoints too.
* **`FindFriendController::findContacts` references a `blocked_users`
  table that doesn't exist.** Likely a pre-existing bug — should be
  `user_blocks` per the `UserBlock` model + migration. Fix before
  testing this endpoint.
* **`unfriend` returns 500 instead of 400 when the users aren't
  friends.** Pre-existing bug in `FriendsController::unfriend` — it
  calls `$this->error('msg', 400)` but the `ApiResponse` trait
  signature is `error($data, $message, $code)`, so 400 is interpreted
  as the message and the code defaults to something else. Trivial fix
  but worth flagging.
* **Web/admin controllers (21 files)** — entirely untested. Tier 5
  in this buildout's plan; revisit if the admin UI becomes
  load-bearing.

## 9. What this baseline means for the buildout

- **Backend feature tests have a usable template** (`ReactionFlowTest`) — the
  shape of subsequent feature tests should match it: `RefreshDatabase`,
  `Storage::fake('public')` where files are involved, `actingAs($user, 'api')`
  for auth, `#[Test]` attribute, assertions against both the JSON envelope
  *and* the database row.
- **App tests have no template yet** beyond pure-logic unit tests. The first
  widget test we add will set the convention; pick the patent-flow widget so
  the convention is set by the highest-stakes case.
- **The 3-of-18 API-controller coverage ratio is the baseline** Phase 2's
  coverage tooling will measure against. Don't expect the coverage *percentage*
  to look good on day one — that's the point.
