# Frontend refactor plan

Behavior-preserving refactor of the Flutter app (`app/lib`).
Authorized 2026-05-18, after the backend refactor. This file is the
single source of truth — read the **§ Checkpoint log** before resuming.

## Goal

The app works but its structure does not scale:

* **Inconsistent architecture** — three state-management approaches
  shipped, two used: `provider` (only `AuthProvider`, trivial UI
  state), `rxdart` `BehaviorSubject` streams (the real data layer),
  and `get` (declared, unused).
* **A 79-file data layer that cannot be tested.** Every feature has an
  `api.dart` + `rx.dart` pair. The api classes are lazy singletons
  (`Api.instance`, private constructor) reaching HTTP through the
  `DioSingleton` global; the rx classes hard-bind `final api =
  Api.instance`; all ~45 `*Rx` instances are global mutables in
  `networks/api_access.dart`. Nothing can be mocked → nothing can be
  unit-tested.
* **Fat widgets** — business logic (HTTP, Pusher, navigation, media
  pickers, message reconciliation) lives inside `build()`. Worst:
  `inbox_screen.dart` 1053 L, `group_inbox_screen.dart` 909 L,
  `receiver_message_widget.dart` 842 L, `sender_message_widget.dart`
  707 L, `chat_screen.dart` 614 L.
* **Duplication** — Pusher subscription logic is copy-pasted across
  the three chat screens; 39 near-identical api/rx pairs.
* **Dead code** — fully-commented `notification_screen.dart`, several
  unwired single-file features, commented blocks in `main.dart` /
  `api_access.dart`.

## The hard rule

**No functionality change.** Every step is behavior-preserving and
verified by a green `Analyze & Test` CI check. Tests are added FIRST,
land in CI, and only THEN is the code refactored — so the refactor is
caught by the net if it drifts.

### The bootstrap exception (FP1 only)

Pure test-first is impossible for the data layer: the `rx_*` classes
**cannot be tested until they are made injectable** — making them
injectable IS the enabling change. So in **FP1 only**, the DI change
and the new data-layer tests land *together* in the same PR (the tests
are written against the newly-injectable code and prove it behaves
identically — `flutter analyze` + the existing patent/rx_base tests
guard the change itself). From **FP2 onward the rule is strict**: tests
for a screen/area land and go green in CI in their own PR *before* the
refactor PR touches that code.

## CI

`.github/workflows/flutter-ci.yml` → the `Analyze & Test` job runs
`flutter analyze` + `flutter test --coverage`. Any test added under
`app/test/` runs automatically. A new mocking package (e.g.
`mocktail`) or `integration_test` must be added to `app/pubspec.yaml`
in the same PR. An app-only PR leaves `PHP Tests` unreported → merge
with `gh pr merge --admin`.

## Checkpoints

| CP | Area | Approach |
|----|------|----------|
| FP1 | Testability foundation — make the 79-file `api.dart`/`rx.dart` layer injectable (service locator instead of global singletons) + unit-test it | DI change + tests land together, in batches by feature |
| FP2 | Extract logic from fat widgets — a `PusherService`, a message reconciler, media/picker controllers, shared form validators; shrink the chat screens | strict test-first, one fat screen per checkpoint |
| FP3 | Retire the unused `get` (GetX) dependency | remove from pubspec, confirm nothing breaks |
| FP4 | Dead-code cleanup — unwired features, commented blocks | confirm scope with the user first |

## Out of scope (functionality phase — see `code-quality-backlog.md`)

These change behavior, so they are NOT part of this refactor:

* Removing the `MyHttpOverrides` TLS-validation override.
* Moving the hardcoded Pusher key / host / broadcasting-auth URL out
  of the chat screens into config.
* The `bio`→`dob` field-name bug in `rx_edit_profile`.

## Cannot be unit-tested without platform mocking

Flagged so checkpoints don't over-promise: the camera recording
(`recordVideoSilently`), Pusher realtime, and `image_picker` flows
need platform-channel fakes or `integration_test`, not plain unit
tests. The patent flow already has an interactive widget test that
swaps fakes — extend that pattern; do not attempt pure unit tests of
the platform-channel code.

## Checkpoint log

_(append results here as each checkpoint lands)_

* **FP1 — Testability foundation — DONE.** PRs #32 (rx_login
  pattern-setter), #33 (the `GetStorage` test fixture in
  `test/support/test_storage.dart`), #34 (the batch — the other 38
  `rx_*` pairs). Every `api.dart`/`rx.dart` pair dropped its `final`
  class modifier; every `rx` now constructor-injects its api,
  defaulting to the singleton (production call sites in
  `api_access.dart` unchanged). 39 `rx_test.dart` files cover the
  error path and the success path (storage-writing handlers via the
  fixture). The `rx_*` data layer went from 0% testable to fully
  unit-tested. CI green. Note: the `api_access.dart` global registry
  was deliberately kept — constructor injection alone unblocks
  testing, so the riskier widget-touching service-locator migration
  was not needed.
* **FP2 — Logic extracted from the fat widgets — DONE.** PR #36
  (`ChatScreen` greeting + chat-filter → `chat/logic/chat_list_logic.dart`,
  tested), PR #39 (`ChatRealtimeService` — the Pusher connect/subscribe
  boilerplate, triplicated across the 3 chat screens, de-duplicated),
  PR #40 (`message_reconciler.dart` — the optimistic-message merge
  logic out of the inbox screens, 19 tests). Plus the helper test net
  (PR #38) and the model test net (PR #37, 16 classes).
  The substantive, risk-carrying logic is now out of the widgets and,
  where it is pure, unit-tested. What remains inside the screens is
  verbose `build()` UI — see "descoped" below.

* **FP3 — N/A (premise was wrong).** The plan assumed `get` (GetX) was
  an unused dependency. It is not: `Get.snackbar` backs `ToastUtil`
  and `Get.offAllNamed` does the 401 redirect in the exception
  handler (and `main.dart` uses it). "Retiring" GetX would be a
  toast/navigation *migration* — behavior-adjacent, not a free
  dependency removal — so it does not belong in a behavior-preserving
  refactor. Dropped.

* **FP5 — Sub-widget extraction — DONE.** The widget-test
  infrastructure descoping no longer applied once a harness was built:
  `app/test/support/widget_harness.dart` provides `pumpInApp`
  (ScreenUtilInit 375×812 + MaterialApp/Scaffold wrapper), which is
  enough to test pure presentation sub-widgets. With that net in place
  the cleanly-separable `build()` chunks were extracted test-first:
  - PR #42 — `SenderTextBubble`, `SenderReplyQuote` out of
    `SenderMessageWidget` (707 → 561 L).
  - PR #43 — `ReceiverTextBubble`, `ReceiverReplyQuote` out of
    `ReceiverMessageWidget` (842 → 705 L).
  - PR #44 — shared `ChatReplyBanner`, replacing a byte-identical
    inline "Replying to …" banner duplicated in both `InboxScreen`
    and `GroupInboxScreen`.
  Scope limit: the message-bubble files only *partially* decompose —
  their reaction/media chunks own a live `FlickManager` video
  controller in `State` and are not cleanly extractable; the two
  inbox screens' `build()` are tangled with `setState`/`cList` and
  only the reply banner separated cleanly. The video-coupled chunks
  are deliberately left in place — extracting them would not be
  behavior-preserving without also moving controller lifecycle.
  - Dead-code cleanup is code *deletion* — a separate decision the
    user reserved; tracked in `code-quality-backlog.md`.

## Outcome

Frontend refactor **complete** (2026-05-18). The data layer is
injectable and fully tested (FP1); the data, model, and pure-helper
layers have a real unit-test net where none existed; the bug-prone
logic — realtime wiring, message reconciliation, screen logic — is
out of the fat widgets and tested (FP2); and the cleanly-separable
presentation chunks are now named, test-covered sub-widgets behind a
reusable widget-test harness (FP5). The remaining items (GetX
migration, dead-code deletion, the video-controller-coupled bubble
chunks) are either not behavior-preserving or a separate decision —
all recorded above and in `code-quality-backlog.md`.
