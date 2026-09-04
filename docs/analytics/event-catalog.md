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
- **`network`** — `wifi` | `cellular` | `none` | `unknown` (from
  `connectivity_plus`; wifi and ethernet both map to `wifi` as unmetered).
- **`scope`** — `private` | `group`.
- **`message_type`** — `text` | `media` | `reaction`.
- **`result`** — `success` | `failure` (for outcome events).
- **send-failure enum** (`failure_reason` on `message_sent` / `reaction_sent` /
  `mark_viewed_result`) — `unauthorized` | `http_4xx` | `http_5xx` | `timeout` |
  `network` | `unknown`. Mapped from the `DioException`; only present on failure.
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
| `country` | string | Coarse country from the DEVICE LOCALE, e.g. `IL`. Region only, never a city and never coordinates. No location permission is requested. Omitted when the platform reports no region. |
| `language` | string | Device language, e.g. `he`. Answers what is worth translating. Omitted when unknown. |
| `ts` | string | ISO-8601 UTC event timestamp. |

---

## Product / usage events (PostHog)

### App lifecycle

| Event (`Events.*`) | Name | Allowlisted props |
|---|---|---|
| `appOpen` | `app_open` | `cold_start_ms` (int), `is_cold_start` (bool) |
| `screenView` | `screen_view` | `screen` (string, route name from a fixed enum — never free text), `previous_screen` (string\|null) |
| `sessionStart` | `session_start` | _(globals only)_ - emitted on launch and on every return to the foreground |
| `sessionEnd` | `session_end` | `elapsed_ms` (int, session length) - emitted when the app is **backgrounded** (`paused` only; `inactive` fires while the app is still on screen) |
| `screenRender` | `screen_render` | `screen` (route name), `screen_render_ms` (int, route push→first painted frame — time-to-interactive) |
| `frameJank` | `frame_jank` | `screen` (route name), `jank_frame_count` (int, frames over the budget), `jank_max_ms` (int, slowest frame), `frame_count` (int, total frames in the window) |

> `frame_jank` is emitted per **window** (every N frames) and only when at least
> one janky frame occurred — a frame is "janky" when its total build+raster span
> exceeds one 60 fps budget (~16 ms). `screen_render` measures time-to-interactive
> per navigation. Both are observational and fire-and-forget.

### Messaging

| Event | Name | Allowlisted props |
|---|---|---|
| `messageSent` | `message_sent` | `message_type` (`text`\|`media`\|`reaction`), `scope` (`private`\|`group`), `send_ms` (int), `result` (`success`\|`failure`), `has_reply` (bool), `failure_reason` (send-failure enum; only on failure) |
| `mediaUploaded` | `media_uploaded` | `upload_ms` (int), `size_bucket` (enum), `network` (enum), `media_kind` (`image`\|`video`), `result` (`success`\|`failure`) |
| `mediaCompressed` | `media_compressed` | `compress_ms` (int, on-send compression before upload), `media_kind` (`image`\|`video`), `size_bucket` (compressed output size), `result` (`success`\|`failure`) |
| `messageReceived` | `message_received` | `message_type`, `scope`, `delivery_ms` (int, Pusher send→receive; nullable) |

### Reaction / patent flow

> These describe the patented silent-recording flow with **metadata only** —
> never the recorded media. Emission is fire-and-forget and must not alter the
> flow (the patent-flow harness runs on any PR touching the send/record path).

| Event | Name | Allowlisted props |
|---|---|---|
| `reactionRecorded` | `reaction_recorded` | `scope`, `record_ms` (int), `record_trigger_reason` (enum: `painted`\|`timeout`\|`immediate`), `result` (`success`\|`failure`), `failure_reason` (enum: `camera_unavailable`\|`permission_denied`\|`init_error`\|`recording_error`\|`null_clip`\|`other`; only on failure) |
| `reactionSent` | `reaction_sent` | `scope`, `upload_ms` (int), `size_bucket`, `result`, `failure_reason` (send-failure enum; only on failure) |
| `reactionViewed` | `reaction_viewed` | `scope` |
| `markViewedToReaction` | `mark_viewed_to_reaction` | `scope`, `elapsed_ms` (int, mark-viewed→reaction uploaded) |
| `markViewedResult` | `mark_viewed_result` | `scope`, `result` (`success`\|`failure`), `failure_reason` (send-failure enum: `unauthorized`\|`http_4xx`\|`http_5xx`\|`timeout`\|`network`\|`unknown`; only on failure) — emitted from the view-inbox/view-group rx layer so a failed mark-viewed (which silently aborts the reaction flow) is observable |
| `reactionSendSkipped` | `reaction_send_skipped` | `scope`, `reason` (`missing_user_id`\|`missing_group_id`\|`null_message_id`) — the media opened but the reaction send hit an early-return |

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
| `mediaLoaded` | `media_loaded` | `scope`, `media_kind` (`image`\|`video`), `network` (`wifi`\|`cellular`\|`none`\|`unknown`, from `connectivity_plus`), `media_load_ms` (int, unblur→decoded/first-frame), `result` (`success`\|`failure`) |
| `mediaExposure` | `media_exposure` | `scope`, `media_kind`, `media_exposure_ms` (int, unblur→hidden) |
| `recordingMediaOverlap` | `recording_media_overlap` | `scope`, `media_kind`, `network`, `overlap_ms` (int), `overlap_pct` (int 0–100), `recording_start_offset_ms` (int, **signed**; negative = recording began before media was visible), `recording_duration_ms` (int), `media_exposure_ms` (int) |
| `mediaTimeline` | `media_timeline` | `scope`, `media_kind`, `network`, and the open-sequence offsets from the tap (t=0), each present only once its segment occurred: `mark_viewed_ms` (tap→mark-viewed response/unblur), `media_ready_ms` (tap→decoded/first-frame), `painted_ms` (tap→first painted frame), `record_start_ms` (tap→silent recording start). The Phase-0 baseline for re-anchoring the recording trigger to the painted frame. |
| `mediaReceivedSealState` | `media_received_seal_state` | `seal_state` (`sealed`\|`open`), `media_kind` (`image`\|`video`), `scope` (`private`\|`group`), `media_type_raw` (string; raw `media_type` as received, `(null)` sentinel when absent — diagnostic for the unsealed-arrival bug) |

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
| `registerStarted` | `register_started` | `method`, `ms_since_first_launch` — the signup form was accepted and an OTP sent |
| `otpVerified` | `otp_verified` | `result`, `ms_since_first_launch` — the email round trip completed |
| `signupCompleted` | `signup_completed` | `ms_since_first_launch` — new account created |
| `firstMessageSent` | `first_message_sent` | `scope`, `message_type`, `ms_since_first_launch` — the activation moment; successful sends only |
| `firstReactionReceived` | `first_reaction_received` | `ms_since_first_launch` — **the aha**: the loop closed and a face came back |
| `consentDecision` | `consent_decision` | `decision` (`granted`\|`declined`) — DG1 recording-consent choice (metadata only) |
| `walkthroughStepShown` | `walkthrough_step_shown` | `step`, `ms_since_first_launch` — one per tip actually shown; `step` is the storage flag, not an index |
| `walkthroughReplayed` | `walkthrough_replayed` | _(globals only)_ — asked for from Profile, as distinct from shown to a newcomer |
| `demoOpened` | `demo_opened` | `ms_since_first_launch` — the demo screen appeared; distinct from tapping Open |
| `demoStarted` | `demo_started` | _(globals only)_ — practice Reacti CTA tapped |
| `demoReactionCompleted` | `demo_reaction_completed` | _(globals only)_ — practice Reacti reached its reveal (funnel "Demo done"). Never carries the captured media. |

### Engagement & social graph

| Event | Name | Allowlisted props |
|---|---|---|
| `groupCreated` | `group_created` | `member_count_bucket` (enum: `2`\|`3-5`\|`6-10`\|`11+`) |
| `groupJoined` | `group_joined` | `group_size_bucket` (same enum) |
| `friendAdded` | `friend_added` | `method`, `ms_since_first_launch` |
| `inviteShared` | `invite_shared` | _(globals only)_ — share sheet invoked for a contact |
| `inviteOpened` | `invite_opened` | _(globals only)_ — "Connect with {Inviter}" screen shown |
| `inviteConnected` | `invite_connected` | _(globals only)_ — invitee tapped Connect (friendship created) |

---

### Permissions, sign-in, and leaving

Added 2026-08-31. Each of these answers a question the rest of the catalog
cannot: **why** a number is what it is.

| Event | Name | Allowlisted props |
|---|---|---|
| `permissionResult` | `permission_result` | `permission` (`camera`\|`microphone`\|`notifications`\|`contacts`), `result` (`granted`\|`limited`\|`provisional`\|`denied`\|`permanently_denied`\|`restricted`\|`not_determined`\|`unknown`), `ms_since_first_launch` |
| `loginResult` | `login_result` | `result` (`success`\|`failure`), `failure_reason` (the send-failure enum; failures only) |
| `friendRemoved` | `friend_removed` | _(globals only)_ |
| `groupLeft` | `group_left` | _(globals only)_ |
| `accountDeleted` | `account_deleted` | _(globals only)_ |

**Why `permission_result` matters most.** A person who refuses the camera
cannot use the app at all, and in every other event in this catalog they are
indistinguishable from someone who chose not to send a reaction. Reading a
denial as disinterest would point the whole product at the wrong problem.

**Emitted only when the answer changes.** A change of mind fires; an unchanged
answer does not. Push permission is re-requested on every launch and returns
the standing answer without showing a dialog, so reporting every call would
make this the app's chattiest event while adding nothing. The last reported
answer is kept per permission in local storage, and an unreadable store means
the event is emitted rather than swallowed.

The consequence for reading: *current state* is each person's **latest**
answer, which is how `scripts/analytics/growth_digest.py` takes it. Counting
raw events would put someone who denied and later allowed into two buckets and
understate denials.

**Photos is deliberately absent.** The app never requests it; the only code
touching `Permission.photos` reads its status for a settings list. An event for
a dialog that never appears would be a permanently empty row.

**`friend_removed` / `group_left` / `account_deleted` carry nothing.** Who was
removed, or which group, is nobody's business and would not change what the
number is read for: whether people are leaving on purpose or drifting away.

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
| `media_persisted_seal_state` | domain hook on media-message save (server mirror of client `media_received_seal_state`) | `seal_state` (`sealed`\|`open`, from `is_blurred` at persist time), `message_type` (`media`\|`reaction`), `scope` (`private`\|`group`) |
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


## Invite loop (server-side counters, not events)

Reacti grows by invitation, so the loop is its own funnel. It is measured with
**counters on the `invites` row**, not with analytics events, because the
landing page is public and anonymous: an analytics script there would mean
cookies and a consent banner for people who have not installed the app.

| column | step |
| --- | --- |
| `opened_count` | landing page rendered (server-side; counts every open, since a link in a group chat is opened many times and that reach is the point) |
| `first_opened_at` | first open, for time-from-share-to-first-open |
| `demo_completed_count` | the web demo reached its reveal, reported by the page |
| `store_clicked_count` | the App Store button was tapped — the last measurable step before Apple takes over |

The install itself is invisible; it becomes visible again only when the account
connects, which the app already reports as `invite_connected`.

**K-factor** = invites that produced a connection ÷ inviters, straight from
these columns. `POST /i/{code}/step/{step}` is public, throttled, and always
answers 204 whatever the code, so it cannot be used to enumerate invites.
