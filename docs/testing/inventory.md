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
Section 3 overstates real coverage *surface*: only three of the nine
classes are actually fired anywhere.

| Event class | Declared | Dispatched in code |
|-------------|---------:|-------------------:|
| `App\Events\MessageSendEvent` | yes | yes — `ChatController::send`, `V2\SingleChatController::send/forward` |
| `App\Events\GroupMessageSendEvent` | yes | yes — `GroupMessageController::sendMessage` |
| `App\Events\Chat\V2\UserTypingEvent` | yes | yes — `V2\SingleChatController` typing |
| `App\Events\MessageReactionEvent` | yes | **no** |
| `App\Events\MessageReadEvent` | yes | **no** |
| `App\Events\MessageDeletedEvent` | yes | **no** |
| `App\Events\GroupUpdatedEvent` | yes | **no** |
| `App\Events\TypingEvent` | yes | **no** (superseded by `UserTypingEvent`) |
| `App\Events\UserOnlineEvent` | yes | **no** |

The six unfired events are dead code. Either wire them up at the
intended trigger points (preferred — the names map to user-facing
realtime UX that is missing), or delete them. Tracked as a separate
follow-up; out of scope for the Phase-3 commit.

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
