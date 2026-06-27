# Deep Research Brief: Making Reacti Faster — Media Load Timing & Reaction Capture

**Prepared for:** Claude Deep Research
**Date:** 2026-06-22
**Owner:** Achia
**Goal of this document:** Give you everything you need to understand Reacti's architecture and its core performance problem, then **research and recommend concrete, proven techniques** (from other apps, papers, SDKs, and engineering practice) to make the app load media dramatically faster and feel smoother — so that the patented "reaction recording" captures the *right* moment instead of the last second.

---

## 0. TL;DR — What we want you to research

Reacti's signature feature silently records a recipient's front-camera reaction when they open a media message. **The recording starts as soon as the "viewed" call succeeds, but the media itself often hasn't downloaded/decoded yet.** By the time the photo or video is actually on screen, 2–3 of our fixed 4 seconds of recording are already gone, so the captured "reaction" is mostly a blank stare at a loading spinner, then a brief flicker of real reaction at the end. The whole app also feels slow when loading lists, chats, and media.

**We need you to research and synthesize:**

1. How fast-media apps (Snapchat, Instagram, WhatsApp, Telegram, BeReal, iMessage) achieve **near-instant media reveal** — prefetching, predecoding, progressive/placeholder strategies, CDN/edge delivery, adaptive formats.
2. How to **synchronize a capture/recording to the actual on-screen visibility of media** (the "first frame painted" / "first meaningful paint" problem on mobile), rather than to a network callback.
3. Specific, implementable techniques for our stack (**Flutter/Dart client, Laravel 11 backend, Pusher realtime, local-disk media on Hostinger, iOS-only**), including the trade-offs and rough expected wins.
4. General mobile **perceived-performance** patterns (skeletons, optimistic UI, image pipelines, list virtualization, cold-start reduction) ranked by impact-vs-effort for a small team.

Please favor **actionable, sourced recommendations** with concrete numbers where they exist, and call out which apply to iOS/Flutter specifically.

---

## 1. What Reacti is

Reacti is an iOS messaging app (live on the App Store; first production release v1.1.0 submitted June 2026). It is built as a monorepo:

- **`app/`** — the client, written in **Flutter / Dart** (iOS only for now).
- **`backend/`** — the API, written in **Laravel 11 (PHP)**, hosted on Hostinger.
- Realtime is delivered over **Pusher Channels** (with self-hosted **Laravel Reverb** as a fallback websocket server).

The product is a private 1:1 and group chat app, but its differentiator is the reaction mechanic below.

### 1.1 The patented core feature (must not break)

When a recipient **opens a media message** (image or video), the app:

1. Shows the media as a **blurred placeholder** with a "Click to view the media" prompt.
2. On tap, calls the backend **`mark-viewed`** endpoint to record that the media was opened.
3. On success, **un-blurs** the media and **silently records the recipient's front camera for 4 seconds** — capturing their genuine reaction.
4. **Uploads that recording back** as a special message of `type: "reaction"`, which the original sender then sees.

This "silent front-camera reaction on open" is the patent-protected flow and the heart of the product. Any solution must preserve it; we just want the captured reaction to align with the moment the media is actually visible.

---

## 2. The problem in detail

### 2.1 The timing/race problem (primary)

The recording is triggered by a **network success callback**, not by the media becoming visible. Concretely, in
`app/lib/features/chat/presentation/widget/receiver_message_widget.dart`, inside `_buildBlurPlaceholder()`:

```dart
// On tap:
final markViewed = widget.isGroup
    ? viewGroupFileRx.viewGroupFile(id: messageId)
    : viewInboxImageRx.viewInboxImage(id: messageId);

markViewed.waitingForSuccess().then((value) async {
  // 1) Media is un-blurred HERE
  setState(() { _isBlurred = false; });
  widget.onUnblur();

  // 2) Recording STARTS HERE — but the image/video may still be
  //    downloading from the network and decoding on the UI thread.
  final videoFile = await recordVideoSilently();
  // 3) ... then upload the reaction
});
```

The recording duration is a **fixed 4 seconds** (`recorder.dart`, `Duration(seconds: 4)`), with no wait for the media to be fetched, decoded, or painted.

**Why this captures the wrong moment:** there is **no prefetch and no preload** of media. The full-resolution image is downloaded and decoded on first render; videos are created on demand. So the sequence the user experiences is often:

```
tap → mark-viewed round-trip → un-blur → [spinner while media downloads/decodes]
     → recording already running... → media finally appears (2–3s in)
     → ~1–2s of real reaction captured before the 4s window ends
```

There **is** an observability hook (`_beginMediaVisibilityWatch()`) that detects when an image actually decodes (`CachedNetworkImageProvider`) or a video first-frames (FlickManager init) — but it is **purely analytical** and does **not** gate or trigger the recording. So we already *measure* the gap; we just don't act on it.

We track a metric called **`overlap_pct`** = the share of the 4-second recording during which the media was actually on screen. Target is **> 80% (p90)**; below 70% is "too slow." We are frequently below target. Related target: **`media_load_ms` < 800 ms (p90)**, "too slow" above 1500 ms.

### 2.2 General slowness (secondary)

Beyond the recording race, the app simply feels slow when loading chats, lists, and media. There is no skeleton/optimistic UI for media (just a `CupertinoActivityIndicator` spinner or a fallback SVG), no low-quality image placeholder (LQIP)/blurhash, no progressive image loading, and media is served directly off the backend's local disk (no CDN). We want the whole experience to feel instant.

---

## 3. Current technical stack & architecture (ground truth)

### 3.1 Client (Flutter / Dart, iOS)

Key packages (from `app/pubspec.yaml`):

- `cached_network_image: ^3.4.1` — image fetch + disk cache. **No blurhash, no LQIP, no progressive loading** configured. Placeholder is a plain spinner or local file (for just-sent images).
- `video_player: ^2.10.1` + `flick_video_player: ^0.9.0` — video playback. A process-wide LRU `VideoControllerCache` (max 50 controllers) exists and even has a `precacheVideos()` method — **but it is not called in the receiver flow**; controllers are created on demand via `VideoPlayerController.networkUrl(...)`.
- `camera` plugin — wrapped by a global `reactionRecorder.record()` for the silent capture.
- `shimmer: ^3.0.0` — present but **not used** for media placeholders.
- `dart_pusher_channels: ^1.2.3` — realtime client.
- State/storage: GetX-style reactive controllers, GetStorage, Firebase (push), DI bootstrapped in `app/lib/main.dart`.

HTTP layer (`app/lib/networks/dio/dio.dart`, `endpoints.dart`):

- **Dio** HTTP client. Base URL from `--dart-define=BASE_URL`, production fallback `https://reacti.io/api`.
- Timeouts: connect **30 s**, receive **10 minutes** (the long receive timeout is for uploads).
- **No retry logic** on failed uploads; **no custom keepalive/connection-pool tuning** (Dart's default client pool only).
- Reaction upload is a `multipart/form-data` POST (`text`, `message_type`, `reply_to_id`, `file`) with a send-progress callback.
- A former `MyHttpOverrides` that accepted all TLS certs has been **removed** (it was defined but never activated).

### 3.2 Backend (Laravel 11, PHP, Hostinger)

- **Media storage is local filesystem, not S3/CDN.** Uploads are moved to `public/uploads/{folder}/` and served directly as `APP_URL/uploads/...` (see `app/Helpers/Helper.php`). There is a discrepancy: a `public` storage disk is configured but media uploads bypass the storage facade and write to `public_path()` directly.
- **No CDN** (no Cloudflare/CloudFront/S3 in front of media). Every media fetch hits the origin server's disk over HTTP.
- Key endpoints (`backend/routes/api.php`, `app/Http/Controllers/Api/Chat/`):
  - `POST /auth/chat/mark-viewed/{message_id}` (1:1) and the group equivalent — sets `is_blurred=false`, `is_viewed=true`, broadcasts `MessageReadEvent`.
  - `POST /auth/chat/send/{receiver_id}` (1:1) and `POST /auth/chat/{group_id}/send` (group) — multipart message/media/reaction send.
- Every endpoint returns one envelope `{success, message, data, code}` with real HTTP status codes.

### 3.3 Realtime (Pusher / Reverb)

- Backend broadcasts `MessageSendEvent` (any message arrives) and `MessageReadEvent` (media viewed) to **private channels** per room/receiver/sender (`chat-room.{id}`, `chat-receiver.{id}`, `chat-sender.{id}`).
- App subscribes via `dart_pusher_channels` with bearer-token channel auth. A new media message appears on the receiver side when `MessageSendEvent` lands → the receiver then sees the blurred placeholder and the open/record flow begins.
- (Note: staging realtime currently uses the `log` driver, not live Pusher — a known infra gap, not relevant to the perf research itself.)

### 3.4 What is explicitly **missing** today (important for your research)

- No media **prefetch/preload** on message receipt or on scroll-approach.
- No **predecoding** of images or video first-frame before reveal.
- No **blurhash / LQIP / progressive (interlaced/progressive JPEG, WebP, AVIF)** strategy.
- No **CDN / edge caching** of media.
- No **adaptive bitrate / streaming** for video (full file fetched).
- Recording is gated on a **network callback**, not on a **first-frame-painted / visibility** signal.
- No **retry/backoff** on reaction upload; no `message_delivered`/`mark_viewed_result` granular telemetry to localize where latency comes from.

---

## 4. Constraints & context for recommendations

- **Platform:** iOS-only, Flutter/Dart client. Recommendations should be feasible in Flutter (or via platform channels to native iOS) and Laravel.
- **Team:** small; favor high-impact, low-to-moderate-effort changes, and flag anything that's a large infra lift (e.g., migrating media to a CDN/object store).
- **Do not break the patent flow:** silent 4 s front-camera capture on media open, uploaded as `type:"reaction"`. We can change *when* recording starts and *how long*/*how* media loads, but the mechanic stays.
- **Hosting:** backend on Hostinger, media on local disk today. A move to object storage + CDN is on the table if justified.
- **Privacy-sensitive:** reactions are camera recordings of real people; any third-party media/CDN/edge service recommendation should note privacy/data-residency implications.

---

## 5. Research questions (please answer these)

### A. Synchronizing capture to actual visibility
1. What is the canonical way, on iOS and in Flutter, to know that an image/video frame has **actually been painted on screen** (first meaningful paint / first frame), and to trigger an action precisely then? Cover Flutter (`ImageStream` listeners, `addPostFrameCallback`, `RawImage`/decode callbacks, `video_player` first-frame events) and any native iOS equivalents worth bridging.
2. Best practices for **gating a side effect (recording) on media readiness** while keeping a fallback timeout so it never hangs. What do well-engineered apps do?
3. Should the recording window be **dynamic** (start on first-frame, run N seconds of *visible* media) rather than fixed 4 s? What approaches exist for "record the reaction window relative to content visibility"?

### B. Making media appear near-instantly
4. **Prefetching strategies** for chat media: prefetch-on-receipt vs. prefetch-on-scroll-approach vs. prefetch-on-app-foreground. How do Telegram/WhatsApp/Signal decide what and when to prefetch? Bandwidth/cost trade-offs.
5. **Placeholder/progressive techniques** ranked by perceived-speed impact: blurhash/ThumbHash, LQIP, dominant-color, progressive JPEG/WebP/AVIF, server-generated tiny thumbnails. What gives the biggest perceived win for least effort in Flutter?
6. **Image pipeline**: optimal formats and sizing for mobile chat (WebP vs. AVIF vs. progressive JPEG), server-side resizing/transcoding, `cached_network_image` tuning, decode-off-main-thread strategies in Flutter to avoid jank.
7. **Video**: first-frame/poster strategies, HLS/adaptive streaming vs. progressive MP4, `faststart`/moov-atom-at-front, short-clip preloading, and what's realistic without a streaming server.
8. **Delivery**: expected latency wins from putting media behind a **CDN/edge** vs. serving from origin disk on Hostinger. Options that are cheap for a small team (Cloudflare, Bunny, S3+CloudFront, etc.), and the privacy considerations for user-generated camera media.

### C. General app smoothness / perceived performance
9. Highest-leverage **perceived-performance** patterns for a chat app: skeleton screens, optimistic UI, list virtualization (`ListView.builder`/`Sliver` best practices), avoiding rebuild storms with GetX, pagination, cold-start reduction.
10. Flutter-specific **jank** sources and fixes (main-isolate work, image decode, large widget rebuilds, shader compilation jank / Impeller on iOS).
11. **Networking** wins: HTTP/2 or HTTP/3 (QUIC) for media, connection reuse/keepalive, request prioritization, parallelism, retry/backoff — what's achievable with Dio + Laravel/Hostinger.
12. A short **measurement playbook**: which client+server metrics to capture to prove improvements (we already have `media_load_ms`, `overlap_pct`, API latency p90), and how leading teams instrument the "tap → media visible" timeline.

### D. Prioritized synthesis
13. Finally, produce a **ranked roadmap** (impact × effort) of changes specific to Reacti's stack: quick wins (days), medium (weeks), and larger bets (infra). For each, give the expected effect on `overlap_pct` / `media_load_ms` / perceived smoothness, and any risk to the patent flow.

---

## 6. Key files (for grounding examples; you don't have repo access but cite these conceptually)

- `app/lib/features/chat/presentation/widget/receiver_message_widget.dart` — blur/unblur, `recordVideoSilently()` trigger, `_beginMediaVisibilityWatch()`.
- `app/lib/helpers/video_controller_cache.dart` — LRU video controller cache + unused `precacheVideos()`.
- `app/lib/common_widget/inbox_custom_network_image.dart` — image rendering via `cached_network_image`.
- `app/lib/networks/dio/dio.dart`, `app/lib/networks/endpoints.dart` — HTTP client, timeouts, base URL.
- `backend/app/Helpers/Helper.php`, `backend/config/filesystems.php` — local-disk media storage.
- `backend/routes/api.php`, `backend/app/Http/Controllers/Api/Chat/` — `mark-viewed` and send endpoints.
- `docs/PLAN-reaction-reliability-2026-06-20.md`, `docs/analytics/perf-workflow.md` — existing problem analysis and perf targets.

---

## 7. Definition of success for this research

A cited report that (a) explains how the best mobile apps make media feel instant and how they sync capture to visibility, (b) maps those techniques onto Reacti's Flutter + Laravel + Pusher + local-disk stack, and (c) ends with a **prioritized, effort-tagged roadmap** we can hand to Claude Code to implement — with the explicit goal of pushing `overlap_pct` reliably above 80% and `media_load_ms` (p90) below 800 ms while keeping the patented reaction flow intact.
