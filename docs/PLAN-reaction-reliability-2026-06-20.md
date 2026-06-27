# PLAN — Reaction reliability: seal, delivery & recording (Branch C, 2026-06-20)

> **Audience:** Claude Code, branch-by-branch.
> **Owner:** Achia (via Cowork). Grounded in `develop` as of 2026-06-20, after
> the avatar fixes (#211, #212) and seal analytics (#209, #210) merged.
> **Rule:** this is the Branch C work from
> `docs/PLAN-chat-avatar-and-media-seal-2026-06-20.md`, expanded. It is an
> **investigation-led** effort on the patent-protected path. Per `CLAUDE.md`,
> anything touching the seal/unblur transition, the recording trigger, the
> reaction upload, `mark-viewed`, or their broadcast events **must** ship with
> an end-to-end regression test. **Do not start a fix phase without Achia's
> explicit go-ahead.**

## The problem, as three distinct failure modes

Achia reports intermittent failures with no clean repro. They are really three
separate bugs, each with its own code path, its own analytics signal, and its
own fix. Keep them separate.

| # | Symptom | Net effect | Primary signal |
|---|---------|-----------|----------------|
| A | Media arrives **already open** (unsealed) | no open-action → no reaction | client `media_received_seal_state = open` (+ `media_type_raw`) |
| B | Media opens correctly but **no reaction is recorded/uploaded** | reaction missing | gap between `mark-viewed` and `reaction_recorded`/`reaction_sent` |
| C | A sent media **never arrives** (or arrives, no reaction) | message/reaction lost | client `message_sent` vs server `media_persisted_seal_state` |

The whole point of the analytics platform is to **see** these. We already have
good coverage in places and real blind spots in others (below). The
recommended first step is to close the blind spots (observability), *then* fix
with data in hand — because none of these reproduce on demand.

---

## Current analytics coverage (what already fires)

Client (`app/lib/analytics/`, instrumented in chat widgets):

- `media_received_seal_state` — sealed vs open at render, with `media_type_raw`. (symptom A signal ✓)
- `reaction_recorded` — after recording; props `scope`, `record_ms`, `result`, `failure_reason` (currently only `null_clip`).
- `reaction_sent` — after upload; `scope`, `upload_ms`, `result`.
- `mark_viewed_to_reaction` — latency from unblur to reaction sent.
- `message_sent` — send result; `message_type`, `scope`, `send_ms`, `result` (success/failure, **no reason**).
- `media_loaded`, `media_exposure`, `recording_media_overlap` — authenticity metrics.

Server (`backend/app/Analytics/`, emitted from model-created hooks in
`AnalyticsServiceProvider`):

- `message_persisted` — every persisted message; `message_type`, `scope`.
- `media_persisted_seal_state` — persisted media seal intent; `seal_state`, `message_type`, `scope`.

> Correction to an earlier note: these two **are** emitted — from the
> `Chat::created` / `GroupMessage::created` hooks, not from the controllers.

## Blind spots (failures that emit NOTHING today)

These are why "we can't point to a pattern." Each is a place a failure happens
silently:

1. **`mark-viewed` fails** (HTTP/timeout/401) → reaction flow returns early, only a `log()`. No event. (`receiver_message_widget.dart` reaction tap → `rx_view_inbox_image/rx.dart`, `rx_view_group_file/rx.dart`)
2. **Camera failure reason is flattened** → `recordVideoSilently()` returns null for *any* of: no camera, permission denied, init failure, recording error — all reported as one `failure_reason: null_clip`. Can't tell permission-denied from hardware. (`reaction_recorder/recorder.dart`)
3. **Missing `userId`/`groupId`** → media unblurs but reaction send is skipped by an early `return`, no event. (`receiver_message_widget.dart`)
4. **Reaction upload throws** → the `sendMessage(...).then(...)` chains have **no `.catchError()`**; an exception is unhandled and the parent never learns. (`receiver_message_widget.dart`)
5. **Widget disposed mid-recording** → no `_isRecording` guard in `dispose()`; callbacks are swallowed. (`receiver_message_widget.dart`)
6. **Send failure reason** → `message_sent` records success/failure but not *why* (timeout vs 4xx vs 5xx vs file-missing). (`rx_send_message/rx.dart`, `chat_send_analytics.dart`)
7. **No delivery/received event** → we can't detect "persisted on server but never delivered to the recipient over Pusher." Nothing fires when a realtime message lands. (`inbox_screen.dart` Pusher `onEvent`)
8. **Optimistic bubble silently removed on send failure** → on failure the local message is `removeWhere`'d, so the sender sees it vanish with no "failed/retry" marker and no event. (`inbox_screen.dart`)

---

## Root-cause hypotheses (to confirm with data, not assume)

**Symptom A — unsealed arrival** (highest-likelihood first):

1. `media_type` arrives `null` or a non-exact value (MIME like `image/jpeg`, casing, etc.) → fails the exact-string seal check (`receiver_message_widget.dart` seal block) → renders open. The `media_type_raw` prop on `media_received_seal_state` is already capturing offenders — **read it first.**
2. `is_blurred` arrives `null`/string (`"1"`,`"true"`) → `isMediaSealed` (`media_seal.dart`) only matches `true`/`1` → open. Realtime parser (`inbox_screen.dart`) defaults a missing `is_blurred` to `0` (open).
3. Server-authoritative `should_show_blur` is parsed into the model but **ignored** by the seal decision (client trusts raw `is_blurred` only).

**Symptom B — no recording/upload:**

1. `mark-viewed` failure (blind spot #1) — currently invisible; instrument before fixing.
2. Camera permission/hardware (blind spot #2) — invisible at the needed granularity.
3. Upload HTTP failure or thrown exception (blind spots #4) — partly visible via `reaction_sent=failure`, but no reason and no catch.
4. Missing ids (blind spot #3) — a wiring bug if it occurs.

**Symptom C — send/delivery drop:**

1. **Broadcast gap** — message persists but the Pusher fan-out fails / recipient isn't subscribed / payload not parsed; backend returns 200, recipient never sees it. No delivery event to detect it (blind spot #7).
2. Upload timeout / no retry on flaky networks (`dio.dart` 10-min receive timeout, **no retry**); optimistic bubble then removed (blind spot #8).
3. Optimistic-vs-server reconciliation race (duplicate or dropped bubble).

---

## Branch plan (each its own branch; recommended order C1 → A → B → C)

### C1 — `feat/analytics-reaction-funnel` (observability; do FIRST)
Purpose: make all three symptoms measurable end-to-end so the fixes are
data-driven. Additive, low-risk, no behavior change.

Add events (register names + props in client `events.dart` allowlist, and
backend `AnalyticsEvents::ALLOWLIST` where server-side):

- `mark_viewed_result` — props `scope`, `result` (success/failure), `failure_reason` (`http_4xx`/`http_5xx`/`timeout`/`network`/`unauthorized`/`unknown`), `media_kind`. Emit in the view-inbox/view-group rx layer.
- Enrich `reaction_recorded.failure_reason` enum → `camera_unavailable` / `permission_denied` / `init_error` / `recording_error` / `null_clip` / `other`. Capture the exception type in `recorder.dart` and thread it out.
- `reaction_send_skipped` — props `scope`, `reason` (`missing_user_id`/`missing_group_id`/`null_message_id`). Emit at the early-returns.
- Enrich `reaction_sent` and `message_sent` with `failure_reason` (same enum as `mark_viewed_result`). Inspect `DioException.type`/status in the rx layer.
- `message_delivered` — props `scope`, `message_type`, `delivery_ms?`. Emit when a realtime message lands in the Pusher `onEvent` (recipient side). This is the missing half that lets us detect persisted-but-not-delivered when joined with server `message_persisted`.

Acceptance: events allowlisted + emitted on staging; verify the full funnel in
PostHog (sealed→open, mark-viewed→recorded→sent, send→persist→delivered). No
behavior change. Tests for the new emit points + opt-out suppression.

### A — `fix/chat-media-arrives-unsealed` (symptom A)
Only after reading C1/existing `media_type_raw` data. Likely: normalize
`media_type` (null/MIME/case → canonical), robust `is_blurred` coercion
(string/null-with-media), fix the realtime missing-`is_blurred` default, and/or
adopt `should_show_blur` as authoritative (verify the **broadcast** payload
carries it before relying on it — REST does). Mandatory end-to-end regression
test covering each offending input variant.

### B — `fix/chat-reaction-not-recorded` (symptom B)
Surface and handle the silent failures regardless of cause: add `.catchError()`
to the reaction send chains; guard `dispose()` while `_isRecording`; decide
behavior when `mark-viewed` fails (retry? keep sealed + surface?) and when
camera/permission fails (request permission, user-visible hint?); fix any
missing-id wiring. Consider a bounded retry for the reaction upload. Regression
test for the mark-viewed→record→upload loop including failure branches.

### C — `fix/chat-media-send-drops` (symptom C)
On send failure, stop silently removing the optimistic bubble — mark it
**failed** with a retry affordance (and emit the failure event). Add a bounded
client retry for transient upload errors. Backend: wrap the `broadcast(...)` in
error handling/logging so a Pusher fan-out failure is observable; confirm
channel/subscription correctness. Regression/contract test for persist→broadcast
and the optimistic reconciliation path.

---

## Conventions (all branches)
Conventional Commits (`feat(analytics):`, `fix(chat):`, `test(chat):`);
`dart format` + `flutter analyze` clean; `pint` clean if backend touched;
allowlist every new event/prop (client and server); honor opt-out; analytics
fire-and-forget (never break rendering or block a request); no secrets; no TLS
weakening. Each fix branch on the patent path ships its regression test.

## Key files index
- `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` — seal condition, reaction tap → `mark-viewed` → `recordVideoSilently` → reaction send; the early-returns and missing `.catchError()`.
- `app/lib/features/chat/data/reaction_recorder/recorder.dart` — camera capture; flattened failure reasons.
- `app/lib/features/chat/data/rx_view_inbox_image/rx.dart`, `.../rx_view_group_file/rx.dart` — `mark-viewed`; failures swallowed.
- `app/lib/features/chat/data/rx_send_message/rx.dart` + `.../api.dart` — send/upload; success/failure, no reason, no retry.
- `app/lib/features/chat/presentation/inbox_screen.dart` / `group_inbox_screen.dart` — list build, seal call site, Pusher `onEvent`, optimistic insert/remove.
- `app/lib/features/chat/presentation/media_seal.dart` — `isMediaSealed`.
- `app/lib/networks/dio/dio.dart` — HTTP clients/timeouts (no retry).
- `app/lib/analytics/events.dart` — event/prop constants + `eventAllowlist`.
- `backend/app/Services/ChatService.php`, `GroupMessageService.php` — persist + `broadcast(...)` (no error handling).
- `backend/app/Events/MessageSendEvent.php`, `GroupMessageSendEvent.php` — Pusher channels/payload.
- `backend/app/Providers/AnalyticsServiceProvider.php` — server persist/seal emits.
- `backend/app/Analytics/AnalyticsEvents.php` — server allowlist.
