# PLAN — Chat avatar fix, media-seal integrity, and seal analytics (2026-06-20)

> **Audience:** Claude Code, working in this repo branch-by-branch.
> **Author of brief:** Achia (via Cowork). Investigation grounded in the
> `develop` branch as of 2026-06-20.
> **Status:** Approved problem statements. Solutions below are *plans* —
> confirm the root cause with Achia before merging any fix.

This document covers three pieces of work, each on its **own branch**:

| # | Branch | Type | Summary |
|---|--------|------|---------|
| A | `fix/chat-avatar-sender-and-initials` | bug | Received-message avatar shows the wrong person; add initials fallback. |
| B | `feat/analytics-media-seal-integrity` | feature | New analytics signal: media arrived **sealed** vs **already-open**. |
| C | `fix/chat-media-arrives-unsealed` | bug | Media occasionally arrives unblurred on the receiver side. |

**Recommended order: B → A → C.** Ship the analytics signal (B) first so we
have production numbers on *how often* and *under which conditions* media
arrives open. That data directly informs the root-cause work in C, which is
currently a hypothesis-driven investigation rather than a one-line fix. A
(avatar) is independent and low-risk, so it can land any time.

Do **not** start a new phase/branch without explicit approval from Achia
(per `CLAUDE.md` → "Active project").

---

## Conventions reminder (applies to all three branches)

Read `docs/conventions.md` before touching code. Highlights that matter here:

- **Conventional Commits:** `fix(chat): ...`, `feat(analytics): ...`, `test(chat): ...`.
- **Dart:** `dart format .` and `flutter analyze` must pass. `StatefulWidget`
  config fields are `final`. Files `lower_snake_case.dart`.
- **PHP:** `./vendor/bin/pint`; one response envelope `{success, message, data, code}`.
- **Never** weaken TLS, and **never** commit secrets / `.env` / service-account JSON.
- **North-star guard (`CLAUDE.md`):** anything touching the blur/unblur
  transition, the recording trigger, the reaction upload path, `mark-viewed`,
  or the broadcast events for these **must** ship with a regression test that
  exercises the full loop end-to-end. Branch C is squarely in this zone.

---

# Branch A — `fix/chat-avatar-sender-and-initials`

## A.1 Problem (confirmed, to the bone)

In a 1:1 chat, the small avatar circle next to a **received** message shows the
**current user's own** photo instead of the **sender's** (the friend's) photo.
Separately, when a user has no profile picture, **no circle renders at all** —
we want an initials placeholder like WhatsApp/Telegram.

### Root cause — confirmed

`app/lib/features/chat/presentation/inbox_screen.dart`

The message-row builder routes correctly:

```dart
// inbox_screen.dart ~line 441
return data.sender?.id == appData.read(kKeyUserId)
    ? SenderMessageWidget(...)     // I sent it
    : ReceiverMessageWidget(...);  // the friend sent it
```

So inside the `ReceiverMessageWidget` branch, **`data.sender` is the friend**
and **`data.receiver` is me (the current user)**. But the avatar passed in is:

```dart
// inbox_screen.dart line 488  ❌ BUG
avatar: data.receiver?.avatar ?? "",
```

It passes `data.receiver` (me) instead of `data.sender` (the friend). That is
exactly why your own photo appears on the friend's messages.

**Group chat is already correct** for comparison —
`app/lib/features/chat/presentation/group_inbox_screen.dart:455`:

```dart
avatar: data.sender?.avatar ?? "",   // ✅ correct
```

### Where the avatar is rendered

`app/lib/features/chat/presentation/widget/receiver_message_widget.dart` (~line 476):

```dart
Positioned(
  bottom: 0, left: 0,
  child: ClipOval(
    child: CustomNetworkImage(urls: widget.avatar, width: 24.w, height: 24.h),
  ),
),
```

`CustomNetworkImage` (`app/lib/common_widget/custom_network_image.dart`) falls
back to a generic "no image" SVG on error — there is **no initials support**
anywhere in the codebase today.

### Model fields available for initials

Both `Receiver` (1:1, `inbox_response.dart`) and `Sender` (group,
`group_inbox_response.dart`) expose: `avatar` (String?), `firstName` (String?),
`lastName` (String?). Initials can be derived from `firstName`/`lastName`.

## A.2 Plan

1. **Fix the owner bug.** In `inbox_screen.dart:488` change
   `data.receiver?.avatar` → `data.sender?.avatar`.
   - Grep the whole chat feature for any other `receiver?.avatar` /
     `receiver.avatar` used in a *received-message* context to be sure this is
     the only occurrence. (`group_inbox_screen.dart` is already correct — leave it.)
2. **Build a reusable initials-avatar widget**, e.g.
   `app/lib/common_widget/avatar_circle.dart`:
   - Props: `String? url, String? firstName, String? lastName, double size`.
   - If `url` is non-empty → render `CustomNetworkImage` in a `ClipOval`.
   - If `url` is empty **or** the network image errors → render a colored
     circle with initials (first letter of first + first letter of last name,
     uppercased; fall back to a single letter, then to a neutral glyph if both
     names are empty).
   - Deterministic background color derived from the name (hash → palette) so
     each person gets a stable color, like Telegram.
3. **Use the new widget** in `ReceiverMessageWidget` (and pass `firstName` /
   `lastName` down from `inbox_screen.dart`; today only the avatar URL string
   is threaded through, so the widget's constructor needs two new `final`
   fields). Reuse the same widget in `group_inbox_screen.dart` for consistency.
4. Consider reusing the widget anywhere else a bare network avatar with no
   fallback is shown (chat list / friends list) — optional, note it but don't
   scope-creep without Achia's ok.

## A.3 Acceptance criteria

- In a 1:1 chat, received messages show the **friend's** avatar; my own photo
  never appears on their messages.
- A user with no profile picture shows an initials circle (stable color),
  not a blank/missing circle, in both 1:1 and group chats.
- `dart format .` + `flutter analyze` clean.
- Widget test for `AvatarCircle`: (a) renders network image when url present,
  (b) renders correct initials when url empty, (c) handles empty names.

---

# Branch B — `feat/analytics-media-seal-integrity`

## B.1 Goal

Add a privacy-safe analytics signal that lets us measure **how often a received
media message arrives already-open (a bug) vs correctly sealed**, broken down
by media kind and scope. This is both a product KPI (seal integrity = the core
feature working) and the diagnostic instrument for Branch C.

## B.2 Existing analytics wiring (use this — don't reinvent)

Client (Flutter), all under `app/lib/analytics/`:

- **Capture seam:** `AnalyticsService.track(String event, Map<String, Object?> properties)`
  in `analytics_service.dart`. It enforces opt-out, hashes identity, and — crucially —
  **drops any event or property not in the allowlist**.
- **Event names + property keys + allowlist:** `events.dart`
  - `Events.*` string constants (snake_case values, e.g. `media_loaded`).
  - `Props.*` property-key constants (snake_case, e.g. `media_kind`).
  - `const Map<String, Set<String>> eventAllowlist` — **an event is silently
    dropped unless its name is a key here, and each property is dropped unless
    listed in that event's set.** This is the #1 gotcha: forget the allowlist
    entry and nothing emits.
- **Identity:** `analytics_identity.dart` — salted SHA-256 of the user id;
  raw id never leaves the device.
- Existing related events to match naming style: `media_loaded`,
  `media_exposure`, `reaction_recorded`, `reaction_sent`, `message_received`,
  with props `scope` (`private`/`group`), `media_kind` (`image`/`video`),
  `result` (`success`/`failure`), `*_ms` timings.

Backend (Laravel), under `backend/app/Analytics/`:

- `Analytics::track(string $event, array $props = [], ?string $userId = null)`.
- `AnalyticsEvents::ALLOWLIST` — server-side allowlist (event ⇒ allowed prop keys).
- Opt-out honored via `AnalyticsConsent` (`X-Analytics-Opt-Out` header or
  `users.analytics_opt_out`). Fire-and-forget transport (never blocks requests).

> Note from memory/CLAUDE context: analytics is **built and staging-verified but
> NOT enabled in production** yet. Shipping B does not by itself turn it on in
> prod — coordinate the prod enablement separately with Achia. But landing the
> event now means it's ready the moment prod analytics is switched on, and it
> works on staging immediately.

## B.3 Plan — recommended event shape

Emit a single event per received media message describing its arrival state,
so the sealed-vs-open ratio is a clean funnel/breakdown in PostHog.

- **Event name:** `media_received_seal_state` (`Events.mediaReceivedSealState`).
- **Properties:**
  - `seal_state`: `"sealed"` | `"open"`  (`Props.sealState`)
  - `media_kind`: `"image"` | `"video"`  (existing `Props.mediaKind`)
  - `scope`: `"private"` | `"group"`  (existing `Props.scope`)
  - `media_type_raw`: the raw `media_type` string as received (existing or new
    prop, e.g. `Props.mediaTypeRaw`) — **important for Branch C**, because one
    leading hypothesis is an unexpected/`null` `media_type` slipping past the
    seal condition. Capturing the raw value tells us if that's happening.

Steps:

1. Add the `Events.mediaReceivedSealState` constant and any new `Props.*`
   constants in `events.dart`.
2. Add the allowlist entry in `eventAllowlist`:
   ```dart
   Events.mediaReceivedSealState: {
     Props.sealState, Props.mediaKind, Props.scope, Props.mediaTypeRaw,
   },
   ```
3. **Instrument at the point of truth — the receiver bubble**, in
   `receiver_message_widget.dart`. The widget already knows everything: it has
   `widget.isBlurred`, `widget.fileType`, and the seal condition at lines
   507–512. Emit **once per media message** (guard against rebuilds — see note)
   in `initState()` after `_isBlurred` is set:
   - `seal_state = "sealed"` when the message *would* show the blur placeholder
     (i.e. `_isBlurred == true` AND `fileType ∈ {image, video, reaction}`),
     else `"open"`.
   - Only emit when the message actually has media (`hasFile` / a media type),
     so text messages don't generate noise.
   - **Dedup:** `initState` runs once per widget instance, but list rebuilds can
     recreate widgets. Key the emit on `messageId` and keep an in-memory
     `Set<int>` of already-reported ids (or emit from the list-building site in
     `inbox_screen.dart`/`group_inbox_screen.dart` where each message is
     processed once on load + once on realtime arrival). Prefer emitting from
     the **list site** so 1:1 and group share the logic and dedup is natural.
   - Wrap in try/catch — analytics must never break rendering.
4. **(Optional, recommended) Backend mirror.** Because the client only sees
   messages it renders, a client-only metric can't see messages that were
   *persisted unsealed at the source*. Consider a server-side
   `media_persisted_seal_state` event emitted where chat media is stored
   (`backend/app/Http/Controllers/Api/Chat/` → `ChatService::send`), recording
   `is_blurred` at persist time with `message_type`/`scope`. Add it to
   `AnalyticsEvents::ALLOWLIST`. This disambiguates "sent unsealed" from
   "sealed correctly but parsed-as-open on the client" — the two competing
   hypotheses in Branch C.

## B.4 Acceptance criteria

- New event(s) defined, allowlisted (client and, if done, backend), and emitted
  on staging; verify they appear in PostHog staging with the expected props and
  no PII (only hashed distinct_id).
- Exactly one `media_received_seal_state` per received media message (no
  rebuild-driven duplicates) — covered by a test/asserted manually on staging.
- Opt-out path verified: with opt-out on, nothing emits.
- `flutter analyze` + `dart format` clean; `pint` clean if backend touched.

---

# Branch C — `fix/chat-media-arrives-unsealed`

## C.1 Problem (confirmed, to the bone)

Intermittently, a received media message renders **already open / unblurred**.
Because it never goes through the tap-to-open flow, `mark-viewed` is never
called and **no silent reaction is recorded** — the core Reacti feature is lost.
Reproduces on both staging and the live App Store app. No reliable repro
pattern yet.

## C.2 What is ALREADY fixed (don't redo this)

The "obvious" type-coercion bug is **already merged into `develop`**. The seal
decision tolerates both the REST `bool` and the realtime `int` forms via
`app/lib/features/chat/presentation/media_seal.dart`:

```dart
bool isMediaSealed(dynamic isBlurred) => isBlurred == true || isBlurred == 1;
```

used at `inbox_screen.dart:494` and `group_inbox_screen.dart:462`. The earlier
`data.isBlurred == 1` (which is `false` for a JSON `true`) is gone. The related
`fix/chat-conversation-media-file-url` (absolute `asset()` file URLs) is also
merged. **So the residual bug is something else.** Treat C as an investigation.

## C.3 The actual seal decision (where to look)

Receiver bubble — `app/lib/features/chat/presentation/widget/receiver_message_widget.dart`:

```dart
// ~line 507 — the ONLY thing that produces the sealed placeholder
if (_isBlurred &&
    (widget.fileType == 'image' ||
     widget.fileType == 'video' ||
     widget.fileType == 'reaction' ||
     widget.messageType == 'reaction')) {
  return _buildBlurPlaceholder();
}
```

`_isBlurred` is seeded from `widget.isBlurred` in `initState` (line 194) and
re-synced in `didUpdateWidget` (lines 211–213). `widget.isBlurred` comes from
`isMediaSealed(data.isBlurred)` at the list site.

## C.4 Prioritized root-cause hypotheses (investigate, confirm with data from B)

1. **`media_type` / `fileType` mismatch (highest priority).** The seal only
   fires when `fileType` is **exactly** `'image'`, `'video'`, or `'reaction'`.
   If a media message arrives with `media_type` that is `null`, empty, or any
   other string (a MIME type like `image/jpeg`, `'photo'`, `'img'`, a
   capitalized variant, etc.), the condition is false and the media renders
   **open** even when `is_blurred` is correctly true. The realtime path reads
   `messageData['chat']['media_type']` raw (`inbox_screen.dart:330`). **Action:**
   audit every value the backend can put in `media_type` (DB + `ChatResource` +
   broadcast payload) and confirm the client's exact-string set covers all of
   them. The `media_type_raw` property added in Branch B will show real-world
   offending values from production.

2. **`is_blurred` absent / null / string on some send paths.** Backend only
   sets `is_blurred = true` when `message_type === 'normal' && $file`
   (`ChatService::send`). Media sent through any other path, or by the **legacy
   prod app (v1.0.9)** whose payload shape differs, may carry `is_blurred`
   null/missing/`"1"`. `isMediaSealed` matches only `true`/`1`, so `null`,
   `"1"`, `"true"` → **open**. The Pusher normalizer (`inbox_screen.dart:325`)
   also only checks `true`/`1`. **Action:** enumerate all message-creation
   paths and the legacy client's payload; decide whether to (a) harden
   `isMediaSealed` to also treat string `"1"`/`"true"` and **null-with-media**
   as sealed, and/or (b) make the backend always set `is_blurred` for any media
   message regardless of `message_type`.

3. **Client ignores the server-authoritative `should_show_blur`.** The backend
   computes `should_show_blur = is_blurred && !is_viewed && (receiver is me)`
   and the model parses it (`inbox_response.dart:331` → `shouldShowBlur`), but
   the seal decision uses raw `is_blurred` and **never reads `shouldShowBlur`**.
   Consider making the seal **server-authoritative**: seal when
   `should_show_blur` is true, falling back to `is_blurred` only if the field is
   absent (older payloads). This collapses the client's guesswork into one
   trusted signal. **Caveat:** confirm the broadcast (Pusher) payload includes
   `should_show_blur`, not just the REST conversation endpoint — if realtime
   omits it, a naive switch would regress realtime sealing. Verify both
   payloads before adopting.

4. **Rebuild / `didUpdateWidget` unseal race.** On unblur the list mutates the
   raw model (`inbox_screen.dart:504` sets `cList[messageIndex].isBlurred = 0`).
   Confirm no *other* `setState`/reconcile path passes `isBlurred == false` for
   a not-yet-viewed message and unseals it via the `didUpdateWidget` re-sync
   (lines 211–213). Lower probability, but cheap to rule out.

## C.5 Plan

1. **Reproduce with data first.** Land Branch B, let it run on staging (and,
   once prod analytics is enabled, prod). Use `media_received_seal_state` +
   `media_type_raw` to see which hypothesis dominates real "open" events.
2. **Confirm the dominant cause with Achia** before coding the fix (per the
   no-new-phase-without-approval rule).
3. **Implement the targeted fix** for the confirmed cause(s). Likely shape:
   broaden/normalize the seal inputs (media_type normalization + robust
   `is_blurred` coercion), and/or adopt `should_show_blur` as authoritative.
   Keep the change minimal and well-commented — this is the patent-protected
   path.
4. **Regression test (mandatory per `CLAUDE.md`).** Add an end-to-end test that
   exercises: media arrives → renders **sealed** → tap → `mark-viewed` →
   `recordVideoSilently()` triggers → reaction uploaded. Include cases for each
   confirmed offending input (e.g. realtime `int` form, unexpected `media_type`,
   `null` is_blurred-with-media). The bug is "sometimes opens" so the test must
   cover the *input variants*, not just the happy path.

## C.6 Acceptance criteria

- For every media-message arrival variant identified in C.4, the receiver
  renders the **sealed** placeholder; tap still drives `mark-viewed` +
  `recordVideoSilently` + reaction upload unchanged.
- Regression test green and wired into CI.
- `media_received_seal_state` open-rate on staging drops to ~0 for the fixed
  variants (measured, not assumed).
- No change to the broadcast contract that could break the live v1.0.9 /
  v1.1.0 clients (mind the `is_viewed`-as-int backwards-compat note in
  `backend/app/Models/Chat.php`).

---

## Suggested commit / PR sequence

1. `feat(analytics): track media-received seal state (sealed vs open)` → Branch B.
2. `fix(chat): show sender avatar on received messages; add initials fallback` → Branch A.
3. *(after data + Achia sign-off)* `fix(chat): seal received media for all media_type/is_blurred variants` + `test(chat): seal→mark-viewed→reaction regression` → Branch C.

## Key files index (for fast navigation)

- `app/lib/features/chat/presentation/inbox_screen.dart` — 1:1 list build, routing, realtime parse. Avatar bug at **L488**; seal call at **L494**; Pusher parse from **L309**.
- `app/lib/features/chat/presentation/group_inbox_screen.dart` — group equivalents (avatar already correct at L455; seal at L462).
- `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` — avatar render (~L476); seal condition (**L507–512**); `recordVideoSilently` / `_buildBlurPlaceholder` (north-star path).
- `app/lib/features/chat/presentation/media_seal.dart` — `isMediaSealed` helper.
- `app/lib/features/chat/model/inbox_response.dart` — `Chat`/`Receiver` model; `isBlurred`/`isViewed`/`shouldShowBlur` parse (L327–331).
- `app/lib/common_widget/custom_network_image.dart` — current avatar image widget (no initials).
- `app/lib/analytics/` — `analytics_service.dart`, `events.dart` (allowlist!), `analytics_identity.dart`.
- `backend/app/Http/Resources/ChatResource.php` / `ChatMessageResource.php` — `is_blurred`, `should_show_blur`, `file` serialization.
- `backend/app/Events/MessageSendEvent.php` — Pusher broadcast payload.
- `backend/app/Http/Controllers/Api/Chat/` + `ChatService` — `send`/`conversation`, where `is_blurred`/`should_show_blur` are set.
- `backend/app/Models/Chat.php` — casts; `is_viewed` int backwards-compat note.
- `backend/app/Analytics/` — `Analytics.php`, `AnalyticsEvents.php` (server allowlist), `AnalyticsConsent.php`.
