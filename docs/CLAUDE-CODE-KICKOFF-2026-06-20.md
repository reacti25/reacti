# Claude Code kickoff — start here (2026-06-20)

Paste the block below into Claude Code from the repo root. It starts Branch B
(analytics). When B is done and reviewed, use the same structure for A, then C.

---

## Prompt — Branch B (`feat/analytics-media-seal-integrity`)

> Read `docs/PLAN-chat-avatar-and-media-seal-2026-06-20.md` in full, then read
> `CLAUDE.md` and `docs/conventions.md`. Confirm back to me which phase this is
> before writing code.
>
> Work **only on Branch B** for now. Create `feat/analytics-media-seal-integrity`
> off `develop`. Do not touch Branch A or C work, and do not start a new phase
> without my approval.
>
> **Probe before you build.** First open and quote the relevant code so we agree
> on reality: `app/lib/analytics/events.dart` (the `Events`, `Props`, and
> `eventAllowlist` map), `app/lib/analytics/analytics_service.dart` (the
> `track()` seam and how the allowlist drops unknown events/props), and the
> receiver-bubble seal condition in
> `app/lib/features/chat/presentation/widget/receiver_message_widget.dart`
> (~lines 507–512) plus the list sites in `inbox_screen.dart` and
> `group_inbox_screen.dart`. Report what you found, then proceed.
>
> **Implement section B.3 of the plan:** a new `media_received_seal_state`
> event with properties `seal_state` (`sealed`/`open`), `media_kind`, `scope`,
> and `media_type_raw` (raw `media_type` string as received — we need this to
> diagnose Branch C). Add the `Events`/`Props` constants and the `eventAllowlist`
> entry. Emit **once per received media message** from the list site (so 1:1 and
> group share one code path and dedup is natural); guard against rebuild-driven
> duplicates and wrap the emit in try/catch so analytics can never break
> rendering. Do not emit for text messages. `seal_state = "sealed"` exactly when
> the bubble would render the blur placeholder, else `"open"`.
>
> The optional backend mirror (B.3 step 4) — propose it but do **not** implement
> it until I say so.
>
> **Constraints:** Conventional Commits (`feat(analytics): ...`); `dart format .`
> and `flutter analyze` must pass; no secrets; no TLS changes. Add a test that
> asserts exactly one event per media message and that opt-out suppresses it.
>
> When done: show me the diff, the new PostHog event shape, and how to verify it
> on staging. **Stop before starting Branch A** and wait for my review.

---

## Prompt — Backend mirror (`feat/analytics-persisted-seal-state`)

> Status: approved by Achia (own branch). Branch B (client `media_received_seal_state`)
> is reviewed and pushed; this is its server-side counterpart so Branch C can
> tell a client-parse bug from a backend send-path bug.
>
> Read `docs/PLAN-chat-avatar-and-media-seal-2026-06-20.md` section B.3 step 4,
> then `CLAUDE.md` and `docs/conventions.md`. Create
> `feat/analytics-persisted-seal-state` **off `develop`** (independent of B).
>
> **Probe first:** open `backend/app/Analytics/Analytics.php`,
> `backend/app/Analytics/AnalyticsEvents.php` (the `ALLOWLIST`),
> `backend/app/Analytics/AnalyticsConsent.php`, and `ChatService::send` (where
> chat media is persisted and `is_blurred` is set). Quote the persist point and
> the existing `messagePersisted` helper, then proceed.
>
> **Implement:** emit a server event `media_persisted_seal_state` at the media
> persist point in `ChatService::send`, recording `is_blurred` **at persist
> time**. Properties: `seal_state` (`sealed`/`open`, derived from `is_blurred`),
> `message_type`, `scope` (`private`/`group`). Mirror the client naming so the
> two events join cleanly in PostHog. Only emit for messages that actually carry
> media. Register `media_persisted_seal_state` + its props in
> `AnalyticsEvents::ALLOWLIST`, add the row to `docs/analytics/event-catalog.md`,
> and honor `AnalyticsConsent` (fire-and-forget; never block the request — match
> the existing transport pattern).
>
> **Constraints:** Conventional Commits (`feat(analytics): ...`); `./vendor/bin/pint`
> clean; one response envelope unaffected; no secrets. Add a Feature/Contract
> test asserting the event fires with the right props on a media send, fires
> with `seal_state=open` when `is_blurred` is false, does **not** fire for text
> sends, and is suppressed under opt-out.
>
> When done: show the diff, the event shape, and how the client+server events
> join (shared keys) to answer "client parse bug vs backend send bug". Do not
> start any other branch — stop for review.

---

## Status (Achia, 2026-06-20)

Branch B (client event) and the backend mirror are both **merged to develop and
verified/deployed on staging**. **Branch A is CLEARED to start.** Branch C
remains **on hold** until we've inspected real `seal_state=open` events in
PostHog staging (the data tells us which root-cause hypothesis to chase).

### Branch A prompt (cleared — go)

> Read `docs/PLAN-chat-avatar-and-media-seal-2026-06-20.md` section "Branch A".
> Create `fix/chat-avatar-sender-and-initials` off `develop`. Fix the avatar
> owner bug (`inbox_screen.dart:488` → `data.sender?.avatar`), build the
> reusable `AvatarCircle` widget with initials fallback (stable per-name color),
> and use it in both 1:1 and group received bubbles. Meet the A.3 acceptance
> criteria including the widget tests. Conventional Commits, format + analyze
> clean. Show me the diff and stop.

---

## Deferred (future, needs Achia's go-ahead)

**Backend default-avatar asymmetry.** `GroupMessageFormatResource` (and the
realtime 1:1 `ChatResource`) serialize a photoless sender's `avatar` as
`asset('default/default_image.jpg')` instead of returning it raw/null like the
1:1 `ChatMessageResource` does. The client now compensates (initials fallback on
default-placeholder URLs, PR #212 merged), so this is not urgent — but the clean
fix is server-side: return null when the user has no photo. It touches a
serialized field the live App Store app consumes, so it **must** go through the
backwards-compat suite (`backwards-compat.yml`) before merging. Log only — do
not start without approval.

---

### After A — Branch C (investigation first, fix only after sign-off)

> Read section "Branch C". This is an **investigation**, not a quick fix — the
> obvious type-coercion bug is already fixed in `develop` (`isMediaSealed`).
> Do NOT re-do that. First, confirm whether the Pusher broadcast payload
> includes `should_show_blur` (the REST endpoint does), and enumerate every
> value the backend can put in `media_type` and every message-creation path's
> `is_blurred` shape (including the legacy v1.0.9 client). Report your findings
> and which of the C.4 hypotheses the evidence (plus Branch B's staging
> analytics) supports. **Wait for my approval of the root cause before coding
> the fix.** The fix must ship with the end-to-end regression test mandated by
> `CLAUDE.md` (media arrives sealed → tap → mark-viewed → recordVideoSilently →
> reaction uploaded), covering each offending input variant.
