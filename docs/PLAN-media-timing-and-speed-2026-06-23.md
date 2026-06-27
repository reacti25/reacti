# Media Timing & Speed — Implementation Plan

**Date:** 2026-06-23
**Operator:** Achia (achia.rosin19@gmail.com)
**Companion documents:**
- `docs/RESEARCH-BRIEF-reaction-timing-2026-06-22.md` (the brief handed to Deep Research)
- Deep Research output: *Reacti Performance & Reaction-Sync Engineering Report* (in Downloads)
- `docs/PLAN-reaction-reliability-2026-06-20.md` (sibling effort — reaction reliability/observability)
- `docs/analytics/perf-workflow.md` (perf metrics + PostHog dashboards)

**Purpose:** Turn the research into an executable, branch-per-optimization roadmap that (1) makes the silent reaction recording capture the *real* reaction by anchoring it to when media is actually on screen, and (2) makes media load fast enough that the app feels instant.

**Constraints (hard, non-negotiable):**
1. **Do not break the patent flow.** blur → tap → `mark-viewed` → un-blur → silent **fixed 4s** front-camera record → upload as `type:"reaction"`. The *only* behavioral change allowed to the mechanic is **when the 4s clock starts** (first-frame-painted instead of the network callback). Every branch touching this path must keep `PatentFlowEventsTest`, `ReactionFlowTest`, `GroupReactionFlowTest` green and add coverage.
2. **Branch discipline:** one optimization = one branch off `develop`, squash-merged back to `develop` after CI + acceptance. Each branch is **deployed to the staging app** for verification (revert/re-apply freely there — that is our primary safety net). `develop → main` only on a release with explicit Achia approval (and per memory: ship the iOS app *before* the backend).
3. **Backwards compatibility:** the live App Store app (v1.0.9 / v1.1.0) must keep working against the backend — `BackwardsCompat/LiveAppV109ChatCompatTest` stays green. Any new message field (e.g. a thumbhash) must be additive and optional.
4. **Privacy:** reaction recordings are real faces. No third-party CDN/object-storage for *reaction* media without a signed DPA + DPIA + EU residency decision (Phase 4 is gated on this).
5. **Measure before/after.** No optimization merges to `develop` claiming a win without the Phase 0 instrumentation proving it on the PostHog perf dashboards.

---

## 0. North Star

`overlap_pct` (share of the 4s recording where media is actually painted on screen) reliably **≥ 80% p90**, and `media_load_ms` **< 800 ms p90** for images (**< 1500 ms** for video), with no regression to patent-flow success rates and no degradation in perceived smoothness. Every change is reversible (behind a flag where risky) and proven on a dashboard.

---

## 1. The lesson driving this plan

The captured "reaction" is mostly a stare at a spinner because **recording is triggered by the `mark-viewed` network callback, not by the media becoming visible**, and there is **no prefetch/placeholder/CDN**, so the media arrives 2–3s into a fixed 4s window. The research confirms this is two separable problems:

- **An ordering bug** (highest leverage, pure client-side, no infra): re-anchor the recording start to *first-frame-painted*. Reacti already has the detection logic in `_beginMediaVisibilityWatch()` — today it only observes; we make it *gate* `recordVideoSilently()`.
- **A speed problem** (compounding wins): placeholders, prefetch, decode sizing, server-side WebP/faststart, and eventually a CDN.

We fix the trigger first (proves out `overlap_pct` cheaply), then attack load time, then general smoothness, then infra.

---

## 2. Conventions every branch follows

- **Branch name:** `<type>/<scope>-<topic>` off `develop` (e.g. `feat/chat-reaction-trigger-on-paint`). Types: `feat`, `fix`, `perf`, `refactor`, `chore`. Scopes in use: `chat`, `analytics`, `app`, `backend`, `ci`, `docs`.
- **Commits:** Conventional Commits, e.g. `feat(chat): anchor reaction recording to first painted frame`.
- **CI gates (must pass before squash-merge):** `Analyze & Test` (flutter), `PHP Tests`, `contract-tests`, `backwards-compat`, and `synthetic-perf`.
- **Analytics:** new event names/props must be added to the allowlists (`app/lib/analytics/events.dart` and backend `AnalyticsEvents::ALLOWLIST`) or they are silently dropped. App emits via `analytics.dispatch(event, props)`; backend via `Analytics::track(...)`.
- **Tests:** each branch adds/updates a widget test (`app/test/...`) and/or feature test (`backend/tests/...`); patent-touching branches must extend the patent regression anchors.
- **Reversibility:** any branch that changes runtime behavior of the patent flow ships behind the feature flag from Phase 0.

---

## 3. Phase-by-phase plan

Phases gate on thresholds: don't start the next phase until the current one's acceptance metric is met on the dashboards.

---

### PHASE 0 — Foundation: measure + make it reversible

Rationale: we can't prove any win without a tap→painted→record timeline, and we have no feature-flag/kill-switch today — both are prerequisites for safely changing the patent trigger.

#### Branch 0.1 — `feat/analytics-timing-timeline`
**Goal:** Instrument the full "tap → media visible → record" timeline so `overlap_pct` and `media_load_ms` are computed from real signals, segmented by media type and network.
**Deliverables:**
- Timestamp and emit each segment: `tap`, `mark_viewed_response`, image `decode` (`ImageStreamListener.onImage`), `painted` (`addPostFrameCallback`), `record_start`, video `first_frame` (`isInitialized`).
- Compute `overlap_pct` from painted-window ∩ record-window; enrich existing `recording_media_overlap` / `media_loaded` events; add props for `media_type`, `network_type`, and per-segment ms. Add `FrameTiming` (`addTimingsCallback`) jank capture.
- Add any new props to `events.dart` + backend allowlist; confirm they land on dashboards 755234 (media load) and 755235 (overlap authenticity).
**Acceptance:** baseline p50/p90/p99 for each segment visible on PostHog, split image vs video. This is the "before" snapshot.
**Risk:** none (observation only). **Depends on:** nothing.

#### Branch 0.2 — `feat/app-feature-flag-posthog`
**Goal:** A minimal kill-switch/flag helper (none exists today) so risky changes — especially the trigger re-anchor — can be toggled without an App Store release. **Decision (approved): support BOTH** a build-time `--dart-define` flag (deterministic per staging build) AND PostHog-native remote flags (instant remote toggle / cohort targeting), with the build-time flag taking precedence when set.
**Deliverables:**
- Resolver order: `--dart-define` override (if present) → PostHog remote flag → safe default (flag absent → current behavior), e.g. `Flags.isEnabled('reaction_trigger_on_paint')`.
- A single documented place to register flags; default-off for in-progress work.
- Unit test for resolver precedence and fallback (flag service unavailable → safe default).
**Acceptance:** a flag can be flipped in PostHog and observed to change behavior in a debug build; default path unchanged when flag service is down.
**Risk:** low. **Depends on:** nothing. (Could be done in parallel with 0.1.)

---

### PHASE 1 — Fix the trigger (target: `overlap_pct` p90 ≥ 80%)

#### Branch 1.1 — `feat/chat-reaction-trigger-on-paint`
**Goal:** Re-anchor `recordVideoSilently()` to first-frame-painted instead of the `mark-viewed` success callback. Keep the patented fixed 4s duration; only move its *start*.
**Deliverables:**
- After `mark-viewed` succeeds and un-blur begins, **arm** a one-shot trigger:
  - Image path: `ImageStreamListener.onImage` (decode) → `WidgetsBinding.instance.addPostFrameCallback` (painted) → fire once.
  - Video path: require `VideoPlayerController.value.isInitialized` plus a painted frame → fire once.
  - **Fallback timeout (~2.5s)** so it never hangs (essential given documented iOS black/late first-frame bugs); whichever of painted-or-timeout wins fires `record()` exactly once (guarded `_recordingFired` flag).
- Reuse/refactor existing `_beginMediaVisibilityWatch()` from observational to *gating*.
- Ship behind flag `reaction_trigger_on_paint` (Branch 0.2); emit `mark_viewed_to_reaction` + new `record_trigger_reason` (`painted` | `timeout`).
**Acceptance:** with the flag on, `overlap_pct` p90 ≥ 80% on dashboard 755235; patent regression tests green; `mark_viewed` success rate and `reaction_sent` upload-success rate unchanged vs. Phase 0 baseline; `record_trigger_reason=timeout` share is low (if high → investigate decode vs. iOS black-frame).
**Risk:** MEDIUM (touches the patent trigger) — mitigated by flag + fallback timeout + regression tests. **Depends on:** 0.1, 0.2.

> **Gate to Phase 2:** lock 1.1 in only if `overlap_pct` p90 ≥ 80% and no patent-flow regression. If still < 70%, profile whether the residual gap is image-decode time or iOS video black-frame, and tune (Phase 2 placeholder + prefetch will also help).

---

### PHASE 2 — Make media appear near-instantly (target: `media_load_ms` p90 < 800 ms image / < 1500 ms video)

These branches are largely independent and can be parallelized, except 2.1 spans app+backend.

#### Branch 2.1 — `feat/chat-thumbhash-placeholder`  *(app + backend)*
**Goal:** Replace the plain spinner under the blur with an instant ThumbHash placeholder, so un-blur reveals content immediately (also lifts `overlap_pct`).
**Deliverables:**
- Backend: on media upload, generate a ThumbHash/BlurHash (via existing `intervention/image ^3.11`) and store it as an **additive, optional** field on the message (keep backwards-compat — old clients ignore it).
- App: add `fast_thumbhash`; render the hash as the un-blur target placeholder. Decode off-main-thread (isolate).
- Allowlist new field; contract test for the new optional field.
**Acceptance:** un-blur shows a representative blur instantly (no spinner); `BackwardsCompatTest` green; perceived media-reveal time drops on dashboard.
**Risk:** low. **Depends on:** none (benefits from 1.1).

#### Branch 2.2 — `feat/chat-prefetch-on-receipt`  *(app)*
**Goal:** Have media already cached locally by the time the user opens it (WhatsApp-style auto-download).
**Deliverables:**
- On `MessageSendEvent` receipt (Pusher), `precacheImage(CachedNetworkImageProvider(url))` for images and wire the **existing-but-unused** `VideoControllerCache.precacheVideos()` for videos.
- Bandwidth guardrails: prefetch videos on Wi-Fi only by default; cap to the most recent N messages.
**Acceptance:** `media_load_ms` p90 drops sharply for opened messages; no unbounded data usage (verify cap + Wi-Fi gate).
**Risk:** low. **Depends on:** none.

#### Branch 2.3 — `fix/chat-image-decode-sizing`  *(app)*
**Goal:** Stop decoding full-res images for small display sizes (memory + jank + paint latency).
**Deliverables:**
- Set `memCacheWidth`/`memCacheHeight` (display size × devicePixelRatio) and `maxWidthDiskCache`/`maxHeightDiskCache` on `InboxCustomNetworkImage` / `cached_network_image`.
**Acceptance:** lower memory + fewer janky frames (FrameTiming) on image-heavy threads; no visual quality regression at display size.
**Risk:** none. **Depends on:** none.

#### Branch 2.4 — `feat/chat-reaction-upload-retry`  *(app)*
**Goal:** Stop silently losing the patented reaction payload on flaky networks (today: no retry, 10-min receive timeout only).
**Deliverables:**
- Bounded retry + backoff on the multipart reaction POST (`dio_smart_retry` or a small interceptor); add a `CancelToken` for navigation-away; emit `reaction_send` result with `attempts`.
**Acceptance:** `reaction_sent` success rate improves on poor networks; no duplicate uploads (idempotency check); upload tests green.
**Risk:** low. **Depends on:** none. *(Note: overlaps with `PLAN-reaction-reliability` — coordinate so we don't double-implement.)*

#### Branch 2.5 — `feat/backend-webp-variants`  *(backend)*
**Goal:** Smaller media payloads (WebP is ~25–34% smaller than JPEG at equal quality).
**Deliverables:**
- On upload, generate sized WebP variants via `intervention/image` (already present); serve the display-appropriate variant. Keep originals.
**Acceptance:** `media_load_ms` p90 down via smaller transfers; `BackwardsCompatTest` green (URLs/format negotiation additive).
**Risk:** low. **Depends on:** none.

#### Branch 2.6 — `feat/backend-mp4-faststart`  *(backend)* — **CONDITIONAL**
**Goal:** Progressive video playback (move `moov` atom to front) + poster/ThumbHash so video first-frame is fast.
**Deliverables:**
- **Pre-req (verification deliverable):** confirm `ffmpeg` is available on Hostinger (it is **not** referenced anywhere today). If unavailable, evaluate a PHP-only `moov` relocator or a managed transcode step — record the decision.
- On MP4 upload: `ffmpeg -i in.mp4 -c copy -movflags +faststart out.mp4` (metadata-only, no re-encode); generate a poster image + ThumbHash.
**Acceptance:** video first-frame time and video `overlap_pct` improve; `ffprobe` confirms `moov` at front.
**Risk:** low functionally; **blocked on ffmpeg availability**. **Depends on:** 2.1 (poster/hash plumbing) ideally.

> **Gate to Phase 3/4:** image `media_load_ms` p90 < 800 ms. If video still > 1500 ms p90, prioritize 2.6 (faststart) and the Phase 4 CDN.

---

### PHASE 3 — General app smoothness

#### Branch 3.1 — `feat/app-shimmer-skeletons`  *(app)*
**Goal:** Replace blank/spinner waits in lists with skeletons; add optimistic UI where missing.
**Deliverables:** wire the **already-present-but-unused** `shimmer` for chat-list and message skeletons; optimistic send state.
**Acceptance:** subjectively smoother loads; no layout shift on content arrival.
**Risk:** none.

#### Branch 3.2 — `perf/chat-rebuild-scoping`  *(app)*
**Goal:** Kill rebuild storms and repaint bleed.
**Deliverables:** tighten GetX `Obx`/`GetBuilder` scopes to the widget bound to a changed `.obs`; `RepaintBoundary` around video/reaction widgets; `const` constructors; confirm Flutter version is recent enough that **Impeller** is active on iOS (shader-jank fix). Optional `itemExtent`/`AutomaticKeepAliveClientMixin` for video rows.
**Acceptance:** fewer >16ms frames (FrameTiming) on scroll; no behavior change.
**Risk:** low (verify keep-alive doesn't leak controllers beyond the LRU cap of 50).

#### Branch 3.3 — `feat/app-native-dio-http3`  *(app)*
**Goal:** HTTP/3 + native connection pooling on iOS.
**Deliverables:** route Dio through `native_dio_adapter` (`cupertino_http`/`NSURLSession`); verify multipart upload parity and progress callbacks.
**Acceptance:** request latency down; **multipart reaction upload byte-for-byte parity** confirmed by test; no upload regressions.
**Risk:** MEDIUM (HTTP stack swap) — keep behind flag; test upload path hard. **Depends on:** ideally after 2.4.

---

### PHASE 4 — Infra (gated on privacy/legal) — **requires Achia + counsel sign-off**

#### Branch 4.1 — `feat/backend-cdn-sent-media`  *(backend)*
**Goal:** Biggest `media_load_ms` win: put **sent** media (sender content, lower privacy risk) behind a CDN with edge caching + HTTP/3.
**Deliverables:** stand up CDN (Bunny.net EU or Cloudflare with EU localization); rewrite sent-media URLs; measure cache-hit ratio. **Reaction (face) media stays on EU origin for now.**
**Acceptance:** sent-media `media_load_ms` p90 sharply down; cache-hit ratio healthy; no change to reaction-media residency.
**Risk:** infra + privacy. **Blocked on:** provider choice + DPA.

#### Branch 4.2 — `feat/backend-object-storage`  *(backend)*
**Goal:** Move media off local disk to object storage (`league/flysystem-aws-s3-v3` is **already** in composer) — scalability + latency, paired with the CDN.
**Deliverables:** migrate `public/uploads/...` to R2/S3-compatible storage; migration/back-compat for existing URLs.
**Acceptance:** parity on serving + deletion; migration tested; no broken historical media.
**Risk:** migration risk. **Blocked on:** 4.1 decision.

**Privacy guardrail (spans 4.1–4.2):** for *reaction* (face) media — EU-resident provider, signed DPA, completed DPIA, short retention + automated deletion, SCCs for any non-EEA transfer. Per GDPR Recital 51 these recordings aren't automatically biometric special-category data (we don't run identification), but treat them conservatively. **Confirm with counsel before any third-party processor touches reaction media.**

---

## 4. Sequencing summary

```
Phase 0 (parallel): 0.1 timeline instrumentation · 0.2 feature-flag helper
        │  (baseline captured)
Phase 1: 1.1 trigger-on-paint  ──gate: overlap_pct p90 ≥ 80%──┐
        │                                                     │
Phase 2 (parallel): 2.1 thumbhash · 2.2 prefetch · 2.3 decode-sizing
                    2.4 upload-retry · 2.5 webp · 2.6 faststart(cond.)
        │  ──gate: media_load_ms p90 < 800ms (img)──┐
Phase 3 (parallel): 3.1 skeletons · 3.2 rebuild-scoping · 3.3 http3
        │
Phase 4 (gated on DPA/DPIA): 4.1 CDN sent-media · 4.2 object storage
```

Recommended first PR to review: **0.1 + 0.2 together** (foundation), then **1.1** (the high-leverage fix) on its own.

---

## 5. What I judged NOT to do now (and why)

- **AVIF** — decodes slower, heavier on older devices; WebP (2.5) is the safe production default. Revisit only for large media later.
- **HLS/DASH adaptive streaming** — overkill for short reaction-length clips; progressive MP4 + faststart (2.6) is sufficient.
- **Native iOS AVPlayer bridging for first-frame** — only if the Flutter-level painted signal + timeout (1.1) proves insufficient for video; it's a last resort, not a first move.
- **Moving reaction (face) media to a CDN now** — privacy-gated; deferred behind DPA/DPIA in Phase 4, and even then sent-media goes first.

---

## 6. Open decisions needed from Achia before we start

1. **Scope of approval:** all four phases, or approve Phases 0–2 now and revisit 3–4 after the trigger fix proves out? (Recommended: approve 0–2, gate the rest on results.)
2. **Feature-flag approach (0.2):** ✅ DECIDED — implement BOTH build-time `--dart-define` and PostHog-native remote flags (dart-define takes precedence). Plus every branch deploys to the staging app for revert/re-apply safety.
3. **ffmpeg on Hostinger (2.6):** do we know if it's available, or should branch 2.6 start with a spike to confirm / find an alternative?
4. **CDN + privacy (Phase 4):** is there appetite to engage counsel for a DPA/DPIA now, or shelve Phase 4 until Phases 1–3 land? Provider lean: Bunny.net (EU-native) vs. Cloudflare (free tier + R2)?
5. **Coordination with `PLAN-reaction-reliability`:** branch 2.4 (upload retry) overlaps that effort — fold it in there, or keep it here?

---

## 7. Key files index

- `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` — `_buildBlurPlaceholder()`, `recordVideoSilently()` (≈L260), `_beginMediaVisibilityWatch()` (≈L312).
- `app/lib/features/chat/data/reaction_recorder/recorder.dart` — fixed-4s capture.
- `app/lib/helpers/video_controller_cache.dart` — LRU cache + unused `precacheVideos()`.
- `app/lib/common_widget/inbox_custom_network_image.dart` — image rendering (decode sizing target).
- `app/lib/networks/dio/dio.dart` — Dio client (retry/HTTP3 targets).
- `app/lib/analytics/events.dart` + `analytics/posthog_analytics_service.dart` — event allowlist + dispatch.
- `backend/app/Helpers/Helper.php` — `uploadImage()`/`fileUpload()` to `public/uploads/` (WebP/faststart/thumbhash targets).
- `backend/composer.json` — `intervention/image ^3.11` (present), `league/flysystem-aws-s3-v3` (present); `spatie/laravel-medialibrary` + ffmpeg (absent).
- Regression anchors: `backend/tests/Feature/Events/PatentFlowEventsTest.php`, `tests/Feature/Patent/ReactionFlowTest.php`, `GroupReactionFlowTest.php`, `BackwardsCompat/LiveAppV109ChatCompatTest.php`.
- CI: `.github/workflows/` — `flutter-ci.yml`, `backend-ci.yml`, `contract-tests.yml`, `backwards-compat.yml`, `synthetic-perf.yml`.
