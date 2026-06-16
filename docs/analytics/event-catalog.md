# Reacti analytics — event catalog

> Single source of truth for every analytics event and its **allowlisted
> properties**. The code abstraction (Phase 1: `AnalyticsService` in the app, the
> `Analytics` emitter in the backend) enforces this catalog: any property not
> listed here is **dropped**, and a unit test **fails the build** if a disallowed
> key is emitted. No ad-hoc string events — every event is a typed constant
> (`Events`) and every property a typed constant (`Props`).
>
> Plan: `docs/PLAN-analytics-stats-2026-06-14.md`. Status: **Phase 0** (this doc +
> config scaffolding). Events are defined here first; code wiring lands in Phase 1
> and is staging-verified before any prod use.

## Privacy rules (non-negotiable — this is a face-recording app)

**NEVER collected / emitted anywhere:**
- Message text or media, camera frames, thumbnails, file names/paths/URLs.
- Names, emails, phone numbers, avatars, precise location.
- Auth tokens, passwords, API/App keys, device push tokens.
- **Raw user ids.** The user id is always **hashed** (pseudonymous) before it
  leaves the device/server — see `distinct_id` below.

**Collected — metadata only:**
- Event name + the allowlisted properties in the tables below.
- Counts, enum types (`text`/`media`/`reaction`), scope (`private`/`group`),
  durations in ms, coarse **size/age buckets** (never exact bytes that could
  fingerprint a file), platform/version, timestamps.

**Enforcement:** the abstraction applies the allowlist per event and hashes the
user id centrally; feature code cannot bypass it (it never calls a vendor SDK
directly). EU data region for both PostHog and Sentry. Retention is configured in
the vendor projects (Achia decides the window).

## Property value conventions

- **Durations** — integer **milliseconds** (`*_ms`).
- **`size_bucket`** — one of `xs` (<256 KB), `sm` (<1 MB), `md` (<5 MB),
  `lg` (<20 MB), `xl` (≥20 MB). Never the exact byte count.
- **`network`** — `wifi` | `cellular` | `other` | `unknown`.
- **`scope`** — `private` | `group`.
- **`message_type`** — `text` | `media` | `reaction`.
- **`result`** — `success` | `failure` (for outcome events).
- Booleans are real booleans; enums are lowercase strings from the sets above.

## Environments — one project, tagged (free-tier)

PostHog's free tier is a **single project**, so staging and production share one
PostHog project (and one Sentry org) and are separated by the **`analytics_env`**
property on every event (`staging` | `production`) and the Sentry `environment`
tag — **not** by separate projects/keys. Filter/segment by `analytics_env` in
dashboards; staging and prod data live side by side but never get confused.
Phase 1 ships **staging-tagged only** until Achia verifies on staging; prod
tagging is enabled (same key, `ANALYTICS_ENV=production`) only after sign-off.

## Global properties (attached to every event by the abstraction)

These are set once centrally, not by feature code. They are part of the
allowlist for every event.

| Property | Type | Meaning / allowed values |
|---|---|---|
| `distinct_id` | string | **Salted** SHA-256 of the user id (`secret_salt:user_id`, secret per-env salt). Pseudonymous and not brute-forceable back to the sequential id; never the raw id. **Absent** before login *and* when no salt is configured (anonymous — we never emit an unsalted, reversible hash). |
| `analytics_env` | string | `production` \| `staging`. Selects/labels the environment; events never mix across envs. |
| `platform` | string | `ios` \| `android`. |
| `app_version` | string | Marketing version, e.g. `1.1.0`. |
| `app_build` | string | Build number, e.g. `11`. |
| `session_id` | string | Random per-app-launch id (not tied to identity). |
| `ts` | string | ISO-8601 UTC event timestamp. |

---

## Product / usage events (PostHog)

### App lifecycle

| Event (`Events.*`) | Name | Allowlisted props |
|---|---|---|
| `appOpen` | `app_open` | `cold_start_ms` (int), `is_cold_start` (bool) |
| `screenView` | `screen_view` | `screen` (string, route name from a fixed enum — never free text), `previous_screen` (string\|null) |
| `sessionStart` | `session_start` | _(globals only)_ |

### Messaging

| Event | Name | Allowlisted props |
|---|---|---|
| `messageSent` | `message_sent` | `message_type` (`text`\|`media`\|`reaction`), `scope` (`private`\|`group`), `send_ms` (int), `result` (`success`\|`failure`), `has_reply` (bool) |
| `mediaUploaded` | `media_uploaded` | `upload_ms` (int), `size_bucket` (enum), `network` (enum), `media_kind` (`image`\|`video`), `result` (`success`\|`failure`) |
| `messageReceived` | `message_received` | `message_type`, `scope`, `delivery_ms` (int, Pusher send→receive; nullable) |

### Reaction / patent flow

> These describe the patented silent-recording flow with **metadata only** —
> never the recorded media. Emission is fire-and-forget and must not alter the
> flow (the patent-flow harness runs on any PR touching the send/record path).

| Event | Name | Allowlisted props |
|---|---|---|
| `reactionRecorded` | `reaction_recorded` | `scope`, `record_ms` (int), `result` (`success`\|`failure`), `failure_reason` (enum: `no_camera`\|`permission_denied`\|`capture_error`\|`null_clip`; only on failure) |
| `reactionSent` | `reaction_sent` | `scope`, `upload_ms` (int), `size_bucket`, `result` |
| `reactionViewed` | `reaction_viewed` | `scope` |
| `markViewedToReaction` | `mark_viewed_to_reaction` | `scope`, `elapsed_ms` (int, mark-viewed→reaction uploaded) |

### Patent authenticity / media UX

> Timing metadata for the viewed-media side of the patent flow — **never** the
> media, frames, or content. The **authenticity** question these answer: was the
> silent reaction recorded *while the recipient could actually see the media*?
> All emission is fire-and-forget on the load-bearing path (the patent-flow
> harness runs on any PR touching it). The exposure window is `unblur →
> media hidden` (widget disposed / left the screen); the recording window is the
> fixed silent-capture window.

| Event | Name | Allowlisted props |
|---|---|---|
| `mediaLoaded` | `media_loaded` | `scope`, `media_kind` (`image`\|`video`), `media_load_ms` (int, unblur→decoded/first-frame), `result` (`success`\|`failure`) |
| `mediaExposure` | `media_exposure` | `scope`, `media_kind`, `media_exposure_ms` (int, unblur→hidden) |
| `recordingMediaOverlap` | `recording_media_overlap` | `scope`, `overlap_ms` (int), `overlap_pct` (int 0–100), `recording_start_offset_ms` (int, **signed**; negative = recording began before media was visible), `recording_duration_ms` (int), `media_exposure_ms` (int) |

`overlap_ms` is the intersection of the recording window `[record_start,
record_start+record_duration]` and the exposure window `[media_visible,
media_hidden]`; `overlap_pct = round(overlap_ms / recording_duration_ms * 100)`,
clamped to `0–100` — the share of the captured reaction that coincided with the
media actually being on screen (the headline authenticity number).

### Growth & funnel

| Event | Name | Allowlisted props |
|---|---|---|
| `registerStarted` | `register_started` | `method` (`email`\|`google`\|`apple`\|`facebook`) |
| `otpVerified` | `otp_verified` | `result` (`success`\|`failure`) |
| `firstMessageSent` | `first_message_sent` | `scope` |
| `consentDecision` | `consent_decision` | `decision` (`granted`\|`declined`) — DG1 recording-consent choice (metadata only) |

### Engagement & social graph

| Event | Name | Allowlisted props |
|---|---|---|
| `groupCreated` | `group_created` | `member_count_bucket` (enum: `2`\|`3-5`\|`6-10`\|`11+`) |
| `groupJoined` | `group_joined` | `group_size_bucket` (same enum) |
| `friendAdded` | `friend_added` | _(globals only)_ |

---

## Performance events / spans (Sentry + custom timings)

Performance is captured as **Sentry transactions/spans** for tracing *and* mirrored
as PostHog numeric props (the `*_ms` fields above) for funnels/trends. Span names:

| Transaction / span | Where | Notes |
|---|---|---|
| `message.send` | app | tap-send → server-ack; child span `media.upload` |
| `media.upload` | app | upload duration + throughput; tagged `size_bucket`, `network` |
| `app.cold_start` | app | launch → first interactive frame |
| `realtime.delivery` | app | send → received on peer (when measurable) |
| `http.server` | backend | per-request; tags `endpoint`, `method`, `status` |
| `message.persist` | backend | DB write of a message; tags `message_type`, `scope` |

Tags allowed on spans: `endpoint` (route name, never with ids interpolated —
use the **route pattern** e.g. `chat/send/{id}`), `method`, `status`, `scope`,
`message_type`, `size_bucket`, `network`, `analytics_env`, `platform`. Never tag
spans with user ids (raw), content, or file identifiers.

---

## Backend events (PostHog server-side + Sentry/Pulse)

| Event / signal | Source | Allowlisted props / tags |
|---|---|---|
| `message_persisted` | domain event on message save | `message_type`, `scope`, `processing_ms` (int) |
| `api_request` | API-metrics middleware | `endpoint` (route pattern), `method`, `status` (int), `latency_ms` (int) |
| (errors) | `sentry-laravel` | exception class + stack; **scrub** request body, headers, tokens, PII before send |
| `synthetic_perf` | scheduled `synthetic-perf.yml` (vs staging) | `flow` (`health`\|`login`\|`send`), `latency_ms` (int), `result` (`success`\|`failure`) — infra-emitted directly to PostHog (not via the app/backend emitter); records server-perceived latency over time |

The backend uses the **same hashed `distinct_id`** (hash of the authenticated
user id with a server-side salt) so app and server events for the same user can
be correlated without identifying them.

---

## Adding a new event (the cheap-to-extend path)

1. Add the event + its allowlisted props **here** first.
2. Add the typed constant to `Events` / `Props` (app) and the backend `Events`.
3. Emit it via the abstraction only: `analytics.track(Events.x, { Props.y: ... })`.
4. The allowlist test enforces this doc — if a prop isn't listed here, the build
   fails. Update this doc and the constants together, in the same PR.
