# Plan — notification deep-link + unread badge (2026-07-09)

Three related features, in the order Achia asked. Phase 1 is a **prerequisite**:
we can't test the tap-to-chat fix without push notifications on staging.

> Cadence: same as the media batch — one change at a time, staging build,
> Achia verifies on-device, then next. `[Achia]` = Firebase/Apple console or
> device test (Claude can't do those). `[Claude]` = code + verification.

## Where we are today (from the code audit)

- Push works on **production** via FCM (`kreait/laravel-firebase`, one Firebase
  project `reacti-app`, bundle `com.reacti.app`).
- **Tapping a notification does nothing** — `NotificationService.handleMessage`
  only logs; the background handler is a no-op. True on prod too.
- The notification **payload carries only title/body/icon** — no chat/room/group
  ids, and the FCM `data` field is unused.
- **Staging has no push**: the staging build's bundle is `com.reacti.app.staging`,
  which isn't registered in Firebase, so it can't get valid tokens.
- **No app-icon badge** anywhere; but the backend already computes a per-chat
  `unread_count` (reused in the chat-list response).

---

## Phase 1 — Push notifications on staging (prerequisite)

**Goal:** the "Reacti Staging" build receives push exactly like the real app, so
Phase 2 is testable. **Simplest path: register the staging bundle as another app
in the EXISTING `reacti-app` Firebase project** — same backend credentials, no
new project.

- **[Achia]** Firebase console → project `reacti-app` → add apps for
  `com.reacti.app.staging` (iOS, and Android if we ship Android). Download the
  staging `GoogleService-Info.plist` (and `google-services.json`).
- **[Achia]** Confirm an **APNs Auth Key** is uploaded to the project (the prod
  app already pushes, so it likely is — an APNs key is per Apple team, so it
  covers the staging bundle too).
- **[Claude]** Wire the staging Firebase config into the **staging build only**
  (flavor-based): the iOS staging build picks the staging plist; add the
  Android staging flavor + its `google-services.json`; add a staging entry to
  `firebase_options.dart`. Verify the prod build is untouched.
- **[Claude]** Verify/fix the iOS `aps-environment` entitlement so TestFlight
  (production APNs) receives push.
- **Build staging → [Achia] test:** send a message between the two staging
  accounts → the recipient gets a push notification (banner + sound). Tapping
  just opens the app for now — that's Phase 2.

**Gate:** notifications must arrive reliably on staging before Phase 2.

---

## Phase 2 — Tap opens the correct chat (the actual fix)

**Goal:** tapping "Avital sent a video" opens *that* conversation, 1:1 or group.
This also fixes production (tap does nothing there today).

- **[Claude] Backend** — add routing ids to the FCM **`data`** field in the
  send path (`ChatService::send`, `GroupMessageService::sendMessage`):
  - 1:1: `type=chat_1to1`, `room_id`, `peer_id`, `sender_name`, `sender_avatar`.
  - group: `type=chat_group`, `group_id`, `group_name`, `group_avatar`,
    `sender_name`.
  - Additive — old app ignores unknown `data`, so it's safe for live users.
    Update the **Contract test** for the send response if shape is asserted.
- **[Claude] App** — implement `handleMessage` to decode the `data` and route via
  `NavigationService` to `InboxScreen` / `GroupInboxScreen` with the right args,
  handling all three entry points: foreground tap, background tap
  (`onMessageOpenedApp`), and cold start (`getInitialMessage`). Guard against
  missing/garbage ids (no crash, fall back to home).
- **[Claude] Test** — the payload→route decoder is pure logic; unit-test it
  (1:1 routes to inbox with correct args, group routes to group inbox, unknown
  type / missing ids → safe no-op). Isolate it like `VideoWatchWindow` so it's
  testable without the FCM platform.
- **Build staging → [Achia] test:** tap a 1:1 notification → lands in that chat;
  tap a group notification → lands in that group; from locked/terminated too.

**Gate:** correct chat opens from all states on staging.

---

## Phase 3 — Unread badge (app icon + in-app)

**Goal:** a small unread number on the app icon, like WhatsApp/Mail.

**Open product decision — what does the number count?**
- **Recommended: number of conversations with anything unseen** (chats). Reacti's
  "unseen" includes unopened media + unwatched reactions, so a raw *message*
  count would inflate and feel naggy (one chat with 8 unopened photos → "8").
  A conversation count stays small and meaningful ("3 chats need you").
- Alternative: total unread *messages* (literal WhatsApp style). Same effort;
  just noisier here. **Achia to confirm before building this phase.**

- **[Claude] App** — add a badge plugin (`flutter_app_badger`), set the badge
  from the chat-list unread data the app already has (recompute on the realtime
  chat-list updates), and **clear/refresh on app foreground**.
- **[Claude] Backend (optional but better)** — include the recipient's badge
  number in the push payload (`aps.badge`) so the icon updates even while the app
  is closed. Reuses `unreadCountForUser/Group`; add a small "total unseen for
  user" helper (conversations or messages per the decision).
- **[Claude] Test** — the total-unseen computation (per the chosen metric).
- **Build staging → [Achia] test:** badge appears/increments on new messages and
  clears when caught up.

---

## Ship

Each phase merges to `develop` as small PRs and rides a staging build. When all
three are verified on-device, they go out as the **next App Store release**
(app-first, then the backend deploy gate) — same process as 1.3.2.

## External setup checklist (Achia / consoles)
- [ ] Firebase: staging apps (`com.reacti.app.staging`) added to `reacti-app`.
- [ ] Firebase: staging `GoogleService-Info.plist` / `google-services.json` downloaded.
- [ ] APNs Auth Key present on the Firebase project.
- [ ] Badge metric decision: conversations (recommended) vs messages.
