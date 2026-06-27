# Handoff to Claude Code — private-chat "black screen" bug on `develop`

**Date:** 2026-05-30
**Operator:** Achia (non-developer; keep explanations short, beginner-friendly)
**Branch in question:** `develop`
**How this was found:** First real on-device test of the staging app (see context below).

---

## 1. Context — what just shipped, and how staging works now

Phase 5 ("staging build on the iPhone via TestFlight") is **done and merged to `develop`.**
Four PRs landed:

1. **`endpoints.dart` reads `BASE_URL` at build time** — `String.fromEnvironment("BASE_URL", defaultValue: "https://reacti.io/api")`. Production is the default; a build can be aimed elsewhere with `--dart-define=BASE_URL=...`.
2. **iOS staging flavor** — a side-by-side app: bundle id `com.reacti.app.staging`, name "Reacti Staging", amber icon. Driven by `app/ios/Flutter/AppIdentity.xcconfig` (production defaults) + `app/ios/Flutter/FlavorOverride.staging.xcconfig` (staging overrides + manual signing), copied to `FlavorOverride.xcconfig` only during CI.
3. **`.github/workflows/ios-testflight.yml`** — on-demand (`workflow_dispatch`) build on a `macos-26` runner, pointed at `https://staging.reacti.io/api`, signed and uploaded to TestFlight. Uses `app/ios/ExportOptions-staging.plist`.
4. **`runs-on: macos-26`** — required because Apple now demands the iOS 26 SDK (Xcode 26).

"Reacti Staging" is now installed on Achia's iPhone via TestFlight, pointed at **`https://staging.reacti.io`** (a sealed sandbox DB, separate from production). It installs alongside the real Reacti app.

**Staging test accounts** (seeded by `backend/database/seeders/StagingTestAccountsSeeder.php`):
- `smoke-a@reacti.test` — "Smoke Alpha", group admin/owner
- `smoke-b@reacti.test` — "Smoke Bravo", member
- They are friends and share a group named **"Smoke Test Group"**.
- Shared password lives offline in `reacti passwords\staging-test-accounts.txt` (NOT in the repo; from `STAGING_SEED_PASSWORD`).

**To run the app against staging locally** (for debugging this bug):
```sh
cd app
flutter pub get
flutter run --dart-define=BASE_URL=https://staging.reacti.io/api --dart-define=APP_KEY_VALUE=staging-testflight
# then log in as smoke-a@reacti.test
```

---

## 2. The bug to fix

On the staging app (i.e. the current `develop` code), in a **one-to-one PRIVATE chat**:

- Opening the private conversation shows **only the friend's name in the top app bar**.
- The **rest of the screen is black / blank** — no messages, no message bubbles, no text-input bar.
- The **GROUP chat works correctly** — it renders and behaves like the production app.

Both sides were live during the test (Achia logged in as `smoke-a` on her iPhone; a second tester logged in as `smoke-b` on another iPhone). Group chat between them worked; the private chat is the broken one.

### Reproduce
1. Build/run the app against staging (command above), or use the "Reacti Staging" TestFlight build.
2. Log in as `smoke-a@reacti.test`.
3. Open the **private** chat with `smoke-b` (Smoke Bravo).
4. Observe: friend's name shows at top, rest of the screen is black.
   (Open the **group** "Smoke Test Group" to confirm it renders fine — it does.)

---

## 3. Where to look (verify, don't assume)

The private and group chats are **separate screens**, which is why one can break while the other works:

- **`app/lib/features/chat/presentation/inbox_screen.dart`** — the PRIVATE one-to-one chat screen. **Prime suspect.**
- `app/lib/features/chat/presentation/group_inbox_screen.dart` — the GROUP chat screen (works; use as the reference/known-good).
- Message-bubble widgets used by the private screen: `presentation/widget/receiver_message_widget.dart`, `sender_message_widget.dart`, `receiver_text_bubble.dart`, `sender_text_bubble.dart`, `receiver_widget.dart`, `send_message_widget.dart`.
- API paths (`app/lib/networks/endpoints.dart`): private conversation is `GET /auth/chat/conversation/{id}` (`EndPoints.inboxMessage`); group is `GET /auth/group/{id}/messages` (`EndPoints.groupInbox`). Send: `/auth/chat/send/{id}` vs `/auth/group/{groupId}/send`.

### Hypotheses to test
- **Most likely: a `develop`-only regression in `inbox_screen.dart`** (a render exception swallowed into a black container, a `Scaffold`/background painted black with no body, a null/late field, or a layout that collapses). `develop` is ~154 commits ahead of `main`/production, and there's an in-flight "big refactor" (`docs/refactor/big-refactor-plan.md`) — a recent change to the private inbox is the likely cause. Check `git log` on `develop` for changes touching `inbox_screen.dart` and the private message widgets.
- **Possible: API shape/empty-data issue** — the staging `GET /auth/chat/conversation/{id}` response might be empty or a different shape than the widget expects, causing the message list build to throw and leave a black screen. Capture the actual staging response and compare to what `inbox_screen.dart` parses. (This is exactly the "API-shape divergence" class the test wall in `docs/PLAN-staging-and-testing-2026-05-24.md` was built to catch — there are contract tests under `backend/tests/Contract/` worth checking/extending.)
- **Less likely: theme/dark-mode** — but group chat shares the theme and renders fine, so a pure theme bug is unlikely.

### Fast way to find it
Run against staging with `flutter run` (command above), open the private chat, and **watch the debug console for the exception/stack trace** when the black screen appears. That will usually point straight at the offending widget/line in `inbox_screen.dart` or a message widget.

---

## 4. Guardrails (from `CLAUDE.md`)

- **Do NOT break the patent flow** — silent front-camera recording when a recipient opens a media message — which lives in this exact private-chat path (`receiver_message_widget.dart`, `recordVideoSilently()` in `_buildBlurPlaceholder()` after `mark-viewed`). If the fix touches the blur/unblur, recording trigger, reaction upload, `mark-viewed`, or its broadcast events, add/update an end-to-end regression test.
- **Do NOT touch production / `main`.** Fix on a branch off `develop`, PR to `develop`, squash-merge (Conventional Commits). Then it can be re-tested on the staging TestFlight build (Actions → "iOS Staging to TestFlight" → Run workflow → `develop`).
- Confirm the fix renders the private chat correctly for `smoke-a`↔`smoke-b` on staging, and that the group chat still works.

---

## 5. One-line summary for the operator

The staging app works end-to-end; the **private (one-to-one) chat screen renders black on `develop`** while the group chat is fine — almost certainly a regression in `app/lib/features/chat/presentation/inbox_screen.dart`. Start by running against staging and reading the console exception.
