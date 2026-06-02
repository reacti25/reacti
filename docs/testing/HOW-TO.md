# Testing — how to run, read, and understand what's going on

This is a plain guide for someone (you, a teammate, future-you) who wants to:

* see whether the tests are passing right now,
* read a failing test and understand what broke,
* run the tests locally once the toolchain is installed,
* know which test file covers which part of the codebase.

If you want the *plan* and history of how this suite was built, read
[`inventory.md`](inventory.md). This document is the operator's manual.

---

## 1. Where the tests run

Tests run on **GitHub Actions** on every push and pull request that
touches `backend/**` or `app/**`. The workflows live in:

* `.github/workflows/backend-ci.yml` — Laravel/PHP suite (PHPUnit).
* `.github/workflows/flutter-ci.yml` — Flutter suite.

### Fastest path: the web UI

* PR checks summary — open the PR, scroll to "Checks":
  `https://github.com/reacti25/reacti/pull/<N>/checks`
* Actions tab for the whole repo:
  `https://github.com/reacti25/reacti/actions`
* Filter to this branch's runs:
  `https://github.com/reacti25/reacti/actions?query=branch%3Afeature%2Ftest-environment`

Click into any run → click into a job (e.g. "PHP Tests") → expand
"Run tests with coverage" to see what every test did.

### From the terminal (gh CLI)

```sh
gh run list --branch feature/test-environment       # most recent runs
gh run view <id>                                    # job summary
gh run view <id> --log                              # full log
gh run view <id> --log-failed                       # only failed step's log
gh pr checks 1                                      # quick status for PR #1
gh run watch <id>                                   # live tail a running job
```

### What a green / red run looks like

A successful PHPUnit run ends with:

```
Tests:    198 passed (377 assertions)
Duration: 1.0s
```

A failed run shows a `FAIL` line near the top for the failing class, a
`FAILED` block with the assertion + file + line near the bottom, and
exits non-zero. Example failure block:

```
FAILED  Tests\Feature\Chat\ChatControllerTest > send requires auth
  Expected response status code [401] but received 302.
  at tests/Feature/Chat/ChatControllerTest.php:39
```

The test name (`send requires auth`) and the source line are what you
need — `git blame` from there tells you who last changed the
controller, and the assertion tells you what they broke.

---

## 2. Running tests locally (once a toolchain is set up)

CI is the source of truth today because neither `php` nor
`flutter`/`dart` is on the maintainer's local `PATH`. Once one is:

### Backend

```sh
cd backend
composer install
php artisan migrate --force          # only first time (in-memory sqlite under test)
php artisan test                     # all tests, with --display-warnings on
php artisan test --filter=PatentFlow # one class
php artisan test --filter='it locks the full patent flow'
```

Note: tests use an in-memory SQLite DB defined in `phpunit.xml`; they
do not touch your real database.

### App

```sh
cd app
flutter pub get
flutter test                                # all tests
flutter test --reporter expanded            # one line per test name
flutter test test/networks/endpoints_test.dart   # one file
flutter test --coverage                     # writes coverage/lcov.info
```

---

## 3. How to read a test file

Every new test file in this suite is laid out the same way. A
typical example, condensed:

```php
namespace Tests\Feature\Auth;

use ...;

/**
 * What this file covers.
 * Why it lives at this layer.
 * Anything *not* covered here and a pointer to where it is.
 */
class RegistrationTest extends TestCase
{
    use RefreshDatabase;     // each test runs in a fresh DB transaction

    #[Test]
    public function register_caches_pending_user_and_sends_otp_email(): void
    {
        // -- ARRANGE -- spin up the world
        Mail::fake();

        // -- ACT -- hit the endpoint exactly like a real client
        $resp = $this->postJson('/api/register', [ ... ]);

        // -- ASSERT -- what we expect the server to have done
        $resp->assertOk();
        $resp->assertJsonPath('data.email', 'alice@example.com');
        $this->assertDatabaseMissing('users', ['email' => '...']);
        Mail::assertSent(EmailVerifyMail::class);
    }
}
```

The patterns to recognize:

* **`use RefreshDatabase`** — every test starts from a clean DB. No
  test can corrupt another.
* **`#[Test]`** — marks a method as a test. Method name is the
  human-readable description ("a user can log in with valid credentials").
* **`$this->actingAs($user, 'api')`** — fakes auth as a real user.
  Used in tests where we want to skip the login step.
* **`Event::fake([SomeEvent::class])`** — captures dispatched events
  in memory so we can assert on them with
  `Event::assertDispatched(...)`. Other events still fire normally.
* **`Mail::fake()`** — same idea for emails.
* **`assertJsonPath('data.id', $expected)`** — drill into JSON response
  using dot-notation.
* **`assertDatabaseHas('table', [...])` / `assertDatabaseMissing(...)`**
  — verify row state in the test DB. Honest end-to-end check.

---

## 4. Where every test lives

```
backend/tests/
├── Unit/
│   ├── ExampleTest.php           — placeholder, will go when more units land
│   └── Models/
│       ├── ChatTest.php          — Chat scopes, accessors, state helpers
│       ├── RoomTest.php          — Room scopes, has-user, get-other-user
│       └── GroupTest.php         — Group isMember / isAdmin / isOwner
└── Feature/
    ├── Auth/
    │   ├── LoginTest.php         — POST /api/login
    │   ├── RegistrationTest.php  — register, resend-otp, verify-email
    │   └── PasswordResetTest.php — forgot, verify-otp, reset, resend
    ├── Chat/
    │   └── ChatControllerTest.php — v1 chat endpoints (list, conversation, room, search, seen, delete-chat)
    ├── Events/
    │   ├── PatentFlowEventsTest.php       — MessageSend/Read/Reaction across the patent loop
    │   ├── MessageDeletedEventTest.php    — broadcast on chat delete
    │   ├── UserPresenceEventsTest.php     — broadcast on login/logout
    │   └── GroupUpdatedEventTest.php      — broadcast on group info change
    ├── Firebase/
    │   └── FirebaseTokenTest.php  — token CRUD per device
    ├── Friends/
    │   ├── FriendRequestTest.php          — send-request (legacy single-case)
    │   ├── FriendRequestEndpointsTest.php — full friend-request CRUD
    │   └── FriendsTest.php                — friend list + unfriend
    ├── Group/
    │   ├── GroupCreateControllerTest.php  — create / list / details
    │   ├── GroupMessageControllerTest.php — send / edit / list / read / delete
    │   └── GroupManageMemberTest.php      — add / remove / promote / demote / leave / delete-group
    ├── Moderation/
    │   ├── ReportUserTest.php             — report user, list reports
    │   └── UserBlockTest.php              — toggle block, blocked list
    ├── Patent/
    │   ├── ReactionFlowTest.php       — 1:1 patent loop end-to-end
    │   └── GroupReactionFlowTest.php  — group patent loop end-to-end
    ├── Privacy/
    │   └── PrivacyTest.php
    ├── Profile/
    │   └── UserProfileTest.php
    └── User/
        └── UserListingTest.php
```

```
app/test/
├── widget_test.dart                — placeholder
├── networks/
│   └── endpoints_test.dart         — every EndPoints URL pinned
└── features/
    └── chat/
        └── widget/
            └── receiver_message_widget_test.dart  — patent-flow widget visual states
```

---

## 5. The most important tests (which to never break)

In rough order of stakes:

1. `Tests\Feature\Patent\ReactionFlowTest` — locks the 1:1 patent flow.
   The whole product depends on this not regressing.
2. `Tests\Feature\Patent\GroupReactionFlowTest` — same loop for groups.
3. `Tests\Feature\Events\PatentFlowEventsTest` — the realtime broadcast
   leg of the patent loop. A drop in this test means a client UI
   regression even if data is correct.
4. `app/test/networks/endpoints_test.dart` — locks every URL the
   client uses. A backend rename without a client rename breaks this.
5. `app/test/features/chat/widget/receiver_message_widget_test.dart`
   — the visual contracts the patent flow's receiver UI depends on.

If a PR breaks one of these, **stop and read the diff before doing
anything else**.

---

## 6. Common failure shapes and what they mean

| Symptom in CI log | What it usually is |
|---|---|
| `Expected response status code [401] but received 302.` | Test used `post()` not `postJson()`. Laravel redirects unauthed HTML requests; switch to `postJson()` to force a JSON 401. |
| `Failed asserting that an array contains 'X'.` | The JSON path you're asserting against doesn't exist — usually a Resource collection shape changed. |
| `SQLSTATE[HY000]: General error: 1 no such table: <foo>` | A migration is missing or the model's table name is wrong. |
| `Tests\…: TypeError` with `assertCount` on `null` | The JSON path you read returned `null`. The response shape isn't what you assumed. |
| `Mail::assertSent(X) called but X was never sent` | Either the code path that sends mail was skipped (validation failed earlier) or `Mail::fake()` came after the action. |
| `Event::fake(...)` then `Event::assertDispatched(X)` fails | Either the event wasn't faked (`Event::fake()` with no args fakes all, with `[X::class]` only fakes X), or the controller really didn't dispatch — read the controller code. |

---

## 7. Adding a new test

1. Pick the right directory by feature area (see §4).
2. Copy the closest existing test file as a template. The convention
   established in this suite is `use RefreshDatabase`, the `#[Test]`
   attribute, factory-driven setup, and the happy + auth +
   validation triad.
3. Run locally if you can, or push and watch CI.
4. If your endpoint requires auth, the standard "no token → 401" test
   uses `$this->postJson(...)` (no `actingAs`). For 403, set up a
   user that doesn't have permission and call with `actingAs($user)`.
5. For an endpoint that broadcasts, fake the event class with
   `Event::fake([X::class])` and assert with `Event::assertDispatched(...)`.

---

## 8. Conventions used in this codebase

* `actingAs($user, 'api')` — use the `api` guard (this app uses JWT
  via `tymon/jwt-auth`).
* JSON requests via `postJson` / `getJson` / `deleteJson` so the
  framework returns proper JSON responses (and 401 instead of 302).
* Storage: `Storage::fake('public')` for any test that uploads files.
* No real HTTP calls — `BROADCAST_CONNECTION=null`, `MAIL_MAILER=array`,
  `QUEUE_CONNECTION=sync`, all set in `backend/phpunit.xml`.

If you need to add a new test for an endpoint and aren't sure what
shape the response has, the safest move is to add the test, push, and
read the actual response in CI's log on the failure — that's usually
faster than guessing.
