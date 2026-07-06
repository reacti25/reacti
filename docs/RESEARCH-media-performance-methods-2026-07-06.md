# Media & loading performance — methods not yet exploited (2026-07-06)

**Author:** Achia (goal) + Claude (research + synthesis)
**Status:** Research report / backlog input. Not a plan — folds into
`docs/PLAN-media-timing-and-speed-2026-06-23.md` and the pending
`docs/BRIEF-dns-and-media-performance-2026-07-01.md`.

**Method:** deep web research (24 sources, 103 claims, 25 adversarially
verified — 20 confirmed / 5 refuted) on how WhatsApp / Instagram / TikTok /
Facebook / YouTube make heavy media feel instant, cross-referenced against a
full inventory of what Reacti already ships. Every item is tagged
**[DONE] / [PLANNED] / [NEW]**.

> **Guardrails that shape everything (do not skip):**
> - **Patent/privacy split** (from the DNS brief): *sent* media may go behind a
>   CDN; *reaction* media (silently-recorded faces) stays on the EU origin until
>   counsel signs a DPA/DPIA. Keep the two on separate paths.
> - Any of these are **production code** → plan/phase approval + patent-flow
>   regression tests if they touch the media/reaction path; **app-first** release
>   ordering as always.
> - **Measure first.** We already emit `media_load_ms`, `overlap_pct`,
>   `cold_start_ms`. Pull the baseline (`scripts/analytics/perf_digest.py`)
>   before/after each change — don't optimise blind.

---

## Already shipped (don't re-do)

cached_network_image disk cache · `memCacheWidth` decode-downscaling on chat
bubbles · local-file optimistic placeholder · precache latest 10 on inbox open ·
video controller LRU cache (50) + preload/warm on receipt (**now cellular too**,
shipped today) · **client-side ~720p H.264 compress-on-send** (shipped today) ·
group-inbox cursor pagination · trigger-record-on-first-paint · bounded
transport-only upload retry · native HTTP/3 adapter (present, **flag-off**) ·
DB indexes + eager loading · full timing analytics.

---

## Tier 0 — Quick wins, no new infrastructure (do first)

### 0.1 Immutable cache headers on media  **[NEW]**
Media files are immutable once uploaded, but we serve `public/uploads/*` with **no
`Cache-Control`/`ETag`**, so clients re-fetch them. Serve:
`Cache-Control: public, max-age=31536000, immutable` + `ETag`.
- **Win:** each image/video downloads **once ever** per device; near-instant on
  re-view; big cut to `media_load_ms` on repeat opens and to origin load.
- **How:** nginx `location /uploads/ { expires 1y; add_header Cache-Control "public, immutable"; }`
  (server/operator lane) — or Laravel headers on the serve path. Cheapest win on
  the board.
- *Source: nginx cache-header guidance (confirmed 3-0).*

### 0.2 Paginate 1:1 conversations  **[NEW — biggest app-speed gap]**
Groups already cursor-paginate, but **1:1 loads the entire history**
(`ChatService.php` `$perPage = 100000`). A long chat = huge query + payload +
memory + slow open.
- **Win:** open-time and memory for any active 1:1 drop from "whole history" to
  "one page"; scroll stays smooth on old threads.
- **How:** mirror the group `before=<id>` cursor path in `ChatService` + the
  app's inbox load-older logic. No infra. Test-gated.

### 0.3 Guarantee MP4 faststart on sent video  **[NEW / improves today's work]**
`-movflags +faststart` moves the MP4 `moov` atom to the front so playback starts
after the first bytes instead of a full download. Our new compress-on-send may or
may not emit faststart — **verify the `video_compress` output**; if not, add a
fast **remux** (`ffmpeg -i in -c copy -movflags +faststart`, no re-encode, no
quality loss).
- **Win:** faster first-frame for every sent video, on top of the size cut.
- **How:** confirm on-device or add a one-line remux (client post-compress, or a
  backend queued job). Consider a one-time backfill of existing files.
- *Source: Mux / mpegflow (confirmed 3-0). NB: research refuted the overstatement
  that faststart is "THE decisive flag" — it's a real, cheap win, not magic.*

### 0.4 Downscale-on-decode everywhere  **[PARTLY DONE → close the gaps]**
We set `memCacheWidth` on chat bubbles, but **decoded image RAM = W×H×4 regardless
of file size**. Confirm every thumbnail slot (avatars, media-picker grid,
previews) sets `memCacheWidth/Height = logicalWidth × devicePixelRatio`.
- **Win:** less memory → fewer OOM/jank events in media-heavy scroll.
- *Source: Flutter docs + case study (confirmed 3-0; treat the "375MB" magnitude
  as illustrative).*

---

## Tier 1 — Medium effort, high perceived-speed

### 1.1 Server-side ThumbHash / BlurHash placeholders  **[PLANNED — Branch 2.1]**
The single best *perceived*-speed trick the big apps use: never show a blank box.
A tiny hash (**ThumbHash ~21 bytes**, or BlurHash ~20–30 chars) precomputed
**server-side at upload** renders a blurred preview instantly while the real image
downloads.
- **Win:** media area is never empty; feels instant even on slow links; near-zero
  bandwidth.
- **How:** compute in Laravel on upload (PHP ThumbHash/BlurHash encoder), store on
  the message/media row, return in the payload; render in
  `cached_network_image`'s `placeholder` (Dart `fast_thumbhash`). **Must** be
  server-side — the client doesn't have the image yet.
- *Source: ThumbHash primary + Wolt BlurHash (confirmed).* 

### 1.2 Server-side resized variants + WebP  **[PLANNED — Branch 2.5 / NEW]**
Never ship a full-res original into a thumbnail slot. Generate 2–3 sized variants
(thumbnail / feed / full) at upload; serve **WebP** where accepted.
- **Win:** list/grid images download a fraction of the bytes; the real fix behind
  0.4.
- **How:** `intervention/image` or a queued vips/ffmpeg job on upload; store as
  static files. Image-first (cheap); full ABR video is deferred (needs a
  transcoding pipeline we don't have).

### 1.3 Flip the native HTTP/3 adapter  **[DONE-but-OFF → validate + enable]**
`native_dio_adapter` (NSURLSession HTTP/3 on iOS) exists behind `Flags.nativeHttp`,
**off**. Enabling gives client-side HTTP/3 / connection reuse — but only pays off
once the **server/CDN speaks HTTP/3** (Tier 2). Validate behind the flag on
staging first.

---

## Tier 2 — The DNS/CDN decision (biggest transport lever, higher effort)

This is where the largest *video* QoE gains live and it resolves the pending
`BRIEF-dns-and-media-performance`.

### 2.1 CDN / edge for SENT media  **[PLANNED — Branch 4.1, privacy-gated]**
Put an edge (Cloudflare / Bunny.net EU) in front of **sent** media only. You get
**QUIC/HTTP3, 0-RTT resumption, anycast, TLS session resumption, byte-range
(Cache-Slice), and cache headers at the edge** — together, for free-ish.
- **Win (measured at Facebook scale):** QUIC cut video stalls **~20%** and improved
  mean-time-between-rebuffering **up to ~22%** (platform-dependent — a ceiling,
  not a guarantee). 0-RTT removes a full round trip for returning clients.
- **Constraint:** **reaction-face media stays on the EU origin** until DPA/DPIA.
  Two paths, enforced.
- **Caveat from research:** self-hosted nginx HTTP/3 won't match a mature edge
  QUIC stack (implementation quality caused up to 20-point VMAF swings) — prefer a
  proven edge provider over rolling your own.
- *Source: Cloudflare + Meta InfoQ + ACM/arXiv survey (confirmed).* 

### 2.2 Object storage (S3 / R2)  **[PLANNED — Branch 4.2]**
`league/flysystem-aws-s3-v3` is already in `composer.json`. Move `uploads/` to
R2/S3 + edge; better durability and the natural CDN origin. Bigger migration (URL
rewrite + back-compat) — pair with 2.1.

---

## Tier 3 — Later / contextual

- **1.x TikTok 3-player carousel + first-frame prebuffer** **[PARTLY — extend]** —
  we cache controllers; a bounded ~3-player pool with *buffered-to-first-frame*
  (not just constructed) gives sub-100ms swipe-to-play. **Mostly relevant only if
  a reels/swipe feed is added** — chat is not a swipe feed, so lower priority
  here. *(Research refuted the specific "500KB/first-2s" prefetch figure — tune
  prefetch depth empirically against `overlap_pct`/`media_load_ms`, don't
  hard-code it.)*
- **Cold-start** **[PARTLY DONE]** — we already defer non-critical init via
  `unawaited`/post-frame. Two more: run the independent blocking inits
  (Firebase / GetStorage / AuthToken) **concurrently** (`Future.wait`) instead of
  sequential `await`s; move any heavy JSON parse off the main isolate with
  `compute()`.
- **Backend response caching** **[GAP]** — a `cache` table exists but no
  `Cache::` usage; cache hot read endpoints (chat list) if they show up in
  `api_request` latency.

---

## Don't act on these (research refuted them)

- `hive_ce` cache metadata being "8× faster" than sqflite (killed 0-3).
- The specific "prefetch first 500KB / 2s" TikTok figure (killed 0-3) — tune
  empirically.
- "Single-bitrate progressive MP4 beats HLS as a general rule" (killed).
- "faststart is THE flag that decides if an MP4 can stream" — overstated; it's a
  real cheap win, not a gate (killed 0-3).

---

## Suggested order (impact-vs-effort, small team)

1. **0.1 cache headers** + **0.2 paginate 1:1** + **0.3 verify/add faststart** +
   **0.4 decode-downscale audit** — cheap, no infra, immediate.
2. **1.1 ThumbHash placeholders** + **1.2 image variants/WebP** — the perceived-
   instant look.
3. **Decide the DNS/CDN** (2.1/2.2) with the privacy split — the big transport win.
4. **1.3 flip HTTP/3** once the edge speaks it; revisit **Tier 3** as needed.

Re-measure with `perf_digest.py` after each. Targets already set in the media-
timing plan: image `media_load_ms` < 800 ms p90, video < 1500 ms, `overlap_pct`
≥ 80 %.
