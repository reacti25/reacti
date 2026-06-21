# PLAN — Chat lazy-load (cursor pagination) for group + 1:1 threads (2026-06-22)

> **Audience:** Claude Code, working branch-by-branch.
> **Status:** Plan only — not implemented. Replaces the current stopgap.
> **Owner sign-off required before coding (per Achia's "only when we're sure").**

## Why this exists

The group/1:1 "messages I sent vanish" bug was root-caused to the group thread
returning only the **oldest 50** messages (the app fetched page 1 of an
`ASC, paginate(50)` endpoint and never loaded more). The shipped fix
(`fix/group-thread-loads-recent-messages`, PR #216) makes the group endpoint
return the **whole thread** (`per_page` default `100000`), matching what the 1:1
endpoint already did (`ChatService::conversation`).

That fix is correct and live, but **loading the entire conversation on every
open does not scale** — a long thread means a large payload, slow first paint,
and high memory. This plan replaces "load everything" with the model mature chat
apps use (WhatsApp/Telegram): **load the newest page, then lazily load older
messages as the user scrolls up.**

The "load all" default stays as the **safety net** for old clients (see
Backward compatibility) and is only superseded for clients that opt in.

## Goals / non-goals

**Goals**
- Open a thread fast: fetch only the **newest N** messages (default N = 30).
- **Scroll up → fetch the next older batch and prepend**, seamlessly.
- Correct under realtime: new messages still arrive at the bottom; no dupes/gaps.
- Apply to **both** group and 1:1 (group first — that's where the pain was).
- Ship without breaking the **live App Store app** (v1.0.9 / v1.1.0).
- Preserve the patent flow (seal/blur → mark-viewed → silent reaction) for
  messages loaded on any page.

**Non-goals (this plan)**
- Search / jump-to-date.
- Full message caching / offline store.
- Realtime delivery itself (separate — staging Pusher is off; see
  `NEEDS-ACHIA.md`).

## Design

### Cursor pagination, not page numbers

Page/offset pagination breaks when new messages arrive mid-scroll (rows shift
between pages → dupes or skips). Use a **cursor** = the message `id`
(auto-increment, monotonic, stable):

- **Newest page:** `GET /messages?limit=30` → the 30 highest-`id` messages.
- **Older page:** `GET /messages?limit=30&before=<oldestLoadedId>` → the 30
  messages with `id < before`, highest-`id` first.
- Response carries `has_more` (are there messages older than this batch) so the
  client knows when to stop. (`id` cursor is robust; `created_at` is a fallback
  tiebreaker only if ids ever prove non-monotonic — they are here.)

Each page is returned **newest-first** from the server; the client orders for
display (see App).

### Backward compatibility (hard constraint)

The live App Store app calls these exact endpoints and must keep working
(app-first golden rule; the `is_viewed`-as-int incident is why we are careful).

- **No `limit`/`before` params (old app) → unchanged behaviour:** return the
  full thread exactly as today (the #216 `per_page=100000` path). The old app is
  unaffected.
- **`limit` present (new app) → cursor pagination** as above.
- Response envelope keys stay; **add** `has_more` (and echo the applied
  `before`/`limit`) under `data.pagination`. Additive only — old clients ignore
  unknown keys. A **Contract test** locks this.

### Backend

- `GroupMessageService::getMessages` and `ChatService::conversation`:
  - When `limit` is provided: `where('id','<',$before)` (when `before` set) →
    `orderBy('id','desc')->limit($limit + 1)`; the extra row determines
    `has_more`, then drop it. Eager-load the caller's per-user blur/status and
    `replyTo` exactly as today, and keep the per-user `should_show_blur` /
    blur computation per message (unchanged semantics).
  - Cap `limit` (e.g. max 100) to bound payloads.
  - No `limit` → existing full-thread behaviour (backward-compat).
- Keep the response under the existing envelope; `data.messages` stays an array;
  add `data.pagination.has_more` + `data.pagination.before`.

### App

The chat list is already a **`reverse: true` ListView with newest-first data**
(`cList[0]` = newest, rendered at the bottom). This makes lazy-load clean:

- **Initial load:** fetch newest 30 → `cList`.
- **Load older:** when the user scrolls near the **top** (i.e. the end of the
  reversed list / `maxScrollExtent`), fetch `before = cList.last.id` and
  **append older messages to the end of `cList`**. Because the list is reversed,
  appending older rows grows the list *upward* and **the visible newest area
  does not jump** — scroll position is naturally preserved (no manual offset
  math).
- Show a small **header spinner** (top of the reversed list) while fetching;
  hide it; stop when `has_more == false` (no more fetches, no infinite spinner).
- **Merge/dedup:** extend the existing `mergeGroupThread` / `mergeInboxThread`
  (from #215) so older batches dedup by `id`, in-flight optimistic entries stay
  at the bottom, and realtime arrivals still prepend (newest). One pure function,
  unit-testable.
- A `getGroupInboxMessage(before:, limit:)` / inbox equivalent on the rx + api
  layers (additive params; default call stays valid).

### Edge cases (call out in implementation)

- **Realtime message arrives while older pages are loaded** → prepend at bottom,
  dedup by id (no gap, no dupe).
- **Reply-jump to a not-yet-loaded message** → load older pages until the target
  id is present (bounded), else fall back to the current estimate-scroll. Small
  sub-task; note if deferred.
- **Deleted/soft-deleted messages** → excluded server-side as today; `has_more`
  computed on the same filtered query.
- **Empty / brand-new thread** → newest page empty, `has_more=false`, no spinner.
- **Patent media on an older page** → must still seal and drive the reaction
  flow; covered by the patent regression below.

## Test plan (ships with the code — no step is "done" without it)

### Backend (`backend/tests/`)
- **Feature — newest page:** `?limit=30` on a 100-message thread returns the
  newest 30, `id`-desc, `has_more=true`.
- **Feature — older page:** `?limit=30&before=<id>` returns the 30 messages
  immediately older than `<id>`, no overlap with the newest page.
- **Feature — end of history:** `before=<oldestId>` → empty list, `has_more=false`.
- **Feature — limit cap:** `?limit=100000` is clamped to the max.
- **Feature — backward-compat:** **no params** still returns the full thread
  (keep/extend `GroupThreadPaginationTest`); the v1.0.9 backwards-compat suite
  (`LiveAppV109...`) stays green.
- **Feature — per-user blur:** a sealed media message returned on a page still
  carries the correct per-viewer `is_blurred` / `should_show_blur`.
- **Contract:** `data.messages` shape unchanged; `data.pagination.has_more`
  added; no removed/renamed keys.
- Mirror the group tests for the 1:1 endpoint.

### App (`app/test/`)
- **Logic (pure):** extend `message_reconciler_test` — appending an older batch
  dedups by id and keeps order; optimistic + realtime entries stay newest;
  end-of-history stops paging.
- **Widget:** scroll-to-top triggers exactly one older fetch; header spinner
  shows then hides; **scroll position preserved** (newest area doesn't jump);
  `has_more=false` ⇒ no further fetch / no infinite spinner; a realtime message
  appends at the bottom while older pages are loaded.
- **Patent regression (mandatory, per `CLAUDE.md`):** a sealed media message
  loaded via an **older** page still renders sealed → tap → `mark-viewed` →
  `recordVideoSilently` → reaction uploaded. The existing patent-flow harness
  stays green.

### Manual / staging
- Open a >50-message group: newest messages show instantly; scroll up loads
  older smoothly with no jump; reaching the top shows "no more" and stops.

## Rollout (de-risked, in order)

1. **Backend cursor pagination** — additive + backward-compatible. Merge →
   staging auto-deploy. Old app and current new app behaviour unchanged
   (they send no `limit`).
2. **App lazy-load** — new TestFlight build; verify on staging against the
   already-deployed backend.
3. **Flip the app to send `limit`** (or it does from the start in step 2). The
   full-thread default remains for any client that doesn't.
4. Once adopted, optionally lower the full-thread default cap (separate, later).

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Break the live App Store app | No-params path returns the full thread (unchanged); contract + v1.0.9 suites gate it. |
| Scroll "jumps" when prepending older | Reversed list + append-older = grows upward; viewport stays put — no offset math. |
| Dupes/gaps from realtime during paging | Dedup by `id` in the shared merge function. |
| Patent flow breaks for paged media | Mandatory end-to-end patent regression on an older-page media message. |
| Large `limit` abuse | Server clamps `limit` to a max. |

## Out of scope / dependencies
- **Realtime delivery to others** is independent and currently off on staging
  (backend uses the `log` broadcaster, not Pusher) — tracked in `NEEDS-ACHIA.md`.
  Lazy-load works regardless; realtime just keeps the newest page fresh.
