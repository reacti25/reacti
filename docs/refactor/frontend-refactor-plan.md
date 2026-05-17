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

* FP1 — not started.
