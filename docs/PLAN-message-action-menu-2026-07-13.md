# PLAN — WhatsApp-style message action menu (2026-07-13)

Owner: Achia. Cadence: **STOP at each phase** for approval before the next.

## Goal

Replace today's swipe/long-press-bottom-sheet interactions with a single
WhatsApp-style **long-press context menu** on every message (text, media,
reaction), for both 1:1 and group chats. Actions vary by message type and
ownership.

Decisions locked (2026-07-13):

- **Menu:** full WhatsApp feel — dimmed background overlay, bubble lifts,
  animated menu anchored to the bubble.
- **Swipe:** keep swipe-to-reply **and** add reply to the menu.
- **Details:** exact times — add `delivered_at` / `read_at`.
- **Delete:** both "delete for me" and "delete for everyone".
- **Delete-for-me:** syncs across the user's devices (server-side per-user).
- **Forward:** multi-select recipients (chats + groups), batch send.

## Action matrix

| Message type      | Reply | Forward | Copy | Edit (own, ≤10 min) | Delete (me / everyone) | Details |
| ----------------- | :---: | :-----: | :--: | :-----------------: | :--------------------: | :-----: |
| Text              |  ✅   |   ✅    |  ✅  |         ✅          |          ✅            |   ✅    |
| Media / image / video | ✅ |   ✅    |  —   |          —          |          ✅            |   ✅    |
| Reaction video    |  ✅   |   ✅    |  —   |          —          |          ✅            |   ✅    |

- **Edit** and **Delete-for-everyone** require ownership. Edit also requires
  ≤10 min since send (enforced **server + client**).
- **Delete-for-me** is available on any message (incl. received).

## Current state (from code audit)

- Reply: swipe (both directions) + `reply_to_id` — **exists**.
- Delete: long-press → 1-row `DeleteMessageSheet`, own sent msgs, hard delete
  for everyone — **exists** (1:1 + group).
- Backend edit: **groups only** (`POST /auth/group/{g}/message/{m}`); no 1:1
  edit endpoint.
- Forward / copy / details: **do not exist**.
- `chats` table: `status` (sent/delivered/read), `is_blurred`, `is_viewed`,
  `timestamps` — **no `read_at`/`delivered_at`**.
- Groups already track per-user reads via `GroupMessageRead` (usable for group
  "seen" times later).
- `Chat` model already exposes a `forwardedFromUser()` relation — verify the
  column in Phase 3 and build on it.

Key files: `app/lib/features/chat/presentation/widget/{receiver,sender}_message_widget.dart`,
`.../delete_message_sheet.dart`, `.../inbox_screen.dart`,
`.../group_inbox_screen.dart`, `app/lib/features/chat/model/inbox_response.dart`,
`backend/routes/api.php`, `backend/app/Http/Controllers/Api/Chat/`,
`backend/app/Models/{Chat,GroupMessage,GroupMessageRead}.php`.

## Phasing (each phase is test-gated and ships independently)

### Phase 1 — Menu shell + zero/low-backend actions
Build once, reuse everywhere.

- New `MessageActionMenu` overlay widget (full WhatsApp feel): captures the
  bubble's position on long-press, shows an `Overlay` with dimmed background,
  the bubble lifted, and an animated action list. One widget, driven by an
  action-list built from `(messageType, isMine)`.
- Wire long-press into **sender, receiver, text, media, reaction** bubbles, 1:1
  **and** the group stub (`group_inbox_screen.dart:594`). Receiver bubbles have
  no long-press today — add it without breaking the blur tap / video playback /
  swipe.
- Actions live now: **Reply** (existing `onReply`), **Copy**
  (`Clipboard.setData`), **Delete-for-everyone** (reuse existing delete; retire
  `DeleteMessageSheet`), **Details (basic)** = sent time (`created_at`) +
  Sent/Delivered/Seen label from `status`.
- Tests: widget tests — correct actions per type/ownership; copy; delete still
  works; patent-flow harness stays green (long-press must not fire the blur
  tap).

### Phase 2 — Edit (text, own, ≤10 min)
- Backend: add 1:1 edit endpoint mirroring `GroupMessageController::editMessage`
  — ownership + 10-min window enforced; stamp `edited_at`.
- App: inline edit mode in the composer (prefilled), client-side 10-min guard,
  "edited" label on edited bubbles.
- Tests: Feature + **Contract** (response now carries `edited_at`); widget test
  for the window gate and label.

### Phase 3 — Forward (multi-select, batch)
- Backend: `POST /auth/chat/forward` accepting a message + a list of recipients
  `[{type: chat|group, id}]`; creates messages in each destination, sets
  `forwarded_from_user_id`, broadcasts per destination. Verify/extend the
  existing forward scaffolding.
- App: `ForwardPickerScreen` — multi-select over chats + groups → batch call;
  "Forwarded" label on forwarded bubbles.
- Tests: Feature + Contract (batch, multi-recipient, forwarded flag); widget
  test for selection + send.

### Phase 4 — Delete-for-me + exact Details times
**Touches the patent path — highest care.**

- Backend:
  - Add `delivered_at` / `read_at` to `chats` (migration). Stamp `read_at` in
    the read/mark-viewed transition and `delivered_at` on delivery.
    `mark-viewed` is the patent trigger → keep the **end-to-end regression
    harness green** and cut a **staging TestFlight build** for on-device
    confirmation.
  - Per-user deletion: `chat_message_deletions` (+ group equivalent) pivot
    `(user_id, message_id)`; a `delete-for-me` endpoint records the row; fetch
    queries exclude the caller's deleted rows (syncs across devices).
- App: "Delete" opens a sub-choice — **Delete for me** / **Delete for everyone**
  (latter own-only). Details shows exact **sent / delivered / seen** times.
- Tests: Feature (stamping, per-user filtering, cross-device sync), Contract
  (new fields), patent regression green; widget tests for the delete sub-choice
  and exact Details.
- **Group Details** (read-by list via `GroupMessageRead`) is a stretch item —
  start with a read count, expand only if wanted.

## Cross-cutting / risk notes

- **API-shape / golden rule:** new fields (`delivered_at`, `read_at`,
  `edited_at`, forwarded flag) are **additive** → safe for the live (old) App
  Store app, but every response-shape change updates its **Contract** test.
  Ship **app-first**; the production backend deploy gate stays unapproved until
  the new app is live.
- **Patent path:** only Phase 4 touches `mark-viewed`; that phase carries the
  regression test + a fresh staging build.
- **Process:** this is net-new product work, outside the active
  staging+testing plan. Confirm we're pivoting to it before Phase 1.

## Open question parked

- None blocking Phase 1. Group "Details" read-by depth deferred to Phase 4.
