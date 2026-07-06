# PLAN — Media & loading performance (2026-07-06)

**Status:** DRAFT — awaiting Achia's review. **No implementation until approved.**
**Owner:** Achia (decisions) + Claude (execution).
**Source of methods:** `docs/RESEARCH-media-performance-methods-2026-07-06.md`
(deep, fact-checked research + full codebase inventory).
**Folds into:** `docs/PLAN-media-timing-and-speed-2026-06-23.md` (branch numbers
referenced) and the pending `docs/BRIEF-dns-and-media-performance-2026-07-01.md`.

This plan lists **what** to do, **what we expect**, **how we'll test it**, and the
**to-dos** — phase by phase. It deliberately stops short of code.

---

## 0. Guardrails (apply to every phase)

1. **Patent/privacy split.** *Sent* media may later go behind a CDN; *reaction*
   media (silently-recorded faces) stays on the EU origin until counsel signs a
   DPA/DPIA. Never route reaction media through a third party for "performance."
2. **Patent flow must not regress.** The 1:1 inbox and group inbox host the
   silent-recording flow. Any phase touching those screens keeps the existing
   patent-flow harness green and, if it touches the blur/record/upload/mark-viewed
   path, adds an end-to-end regression test.
3. **App-first releases.** Ship app changes to the App Store before any backend
   change that alters a response shape. Contract tests guard shape changes.
4. **Measure first, measure after.** Use `scripts/analytics/perf_digest.py`
   (`media_load_ms`, `cold_start_ms`, `overlap_pct`) to record a before/after for
   every phase. A change without a measured delta is not "done."
5. **One phase = one (or few) small PR(s)** to `develop`, squash-merged, both
   required CI checks green, then a **STOP checkpoint** for Achia before the next
   big phase — same cadence as the app-hardening plan.
6. **Server/operator lane.** nginx / VPS config changes are the operator's lane
   (see the ops playbook). Where a win needs server config, the plan says so and
   provides an app/Laravel-side alternative where one exists.

---

## 1. Success metrics (how we judge the whole plan)

Targets (carried from the media-timing plan; confirm the baseline in P0):

| Metric | Target |
|---|---|
| Image `media_load_ms` p90 | < 800 ms |
| Video `media_load_ms` p90 (first frame) | < 1500 ms |
| **Repeat-view** media load (cached) | ≈ 0 ms (served from cache) |
| `overlap_pct` avg (authenticity) | ≥ 80 % |
| 1:1 chat open time / payload | bounded to one page, not full history |
| `cold_start_ms` p90 | ≤ current, ideally < 1500 ms |

Each phase below names the specific metric it should move.

---

## 2. Phases

### P0 — Baseline capture *(prep, no code)*
- **Goal:** record today's numbers so every later phase has a before/after.
- **Expectation:** a short baseline table (image/video `media_load_ms` p50/p90,
  repeat-view, `cold_start_ms`, `overlap_pct`), split by network where available.
- **To-dos:**
  - [ ] Run `perf_digest.py --env staging --days 14` (needs `POSTHOG_READONLY_KEY`
        — **decision-gate for Achia:** provide the read-only key, or accept
        dashboard-only baselines).
  - [ ] Record numbers in this doc under an appended "Baseline" section.
- **Testing:** n/a (data capture).
- **Risk:** low. Blocked only if the read-only key isn't available.

---

### P1 — Immutable cache headers on media  *(Tier 0.1 — cheapest win)* **[NEW]**
- **Goal:** stop clients re-downloading immutable media on every view.
- **Change:** serve `/uploads/*` with `Cache-Control: public, max-age=31536000,
  immutable` + `ETag`.
- **Expectation:** repeat-view media load drops toward ≈ 0 ms; origin egress and
  `media_load_ms` on re-open fall sharply. No change to first-view.
- **To-dos:**
  - [ ] Decide the seam: **nginx** `location /uploads/` (operator lane) **or**
        a Laravel response-header path if media ever routes through PHP.
  - [ ] Apply headers; keep reaction vs sent media on their existing paths.
- **Testing:**
  - [ ] Backend/integration test (or a documented `curl -I` check) asserting the
        headers on an uploaded media URL.
  - [ ] Manual: re-open a chat with media, confirm 304/`from cache`.
- **Risk:** low. If nginx-side, needs the operator; the header values are safe for
  immutable content (filenames are unique per upload).

---

### P2 — Paginate 1:1 conversations  *(Tier 0.2 — biggest app-speed gap)* **[NEW]**
- **Goal:** stop 1:1 chats loading the entire history (`ChatService` `perPage =
  100000`); mirror the group cursor pagination.
- **Expectation:** 1:1 open time, payload size, and memory bounded to one page;
  old threads open fast and scroll smoothly; parity with groups.
- **To-dos:**
  - [ ] Backend: add `limit` (clamped) + `before=<id>` cursor + `hasMore` to the
        1:1 conversation endpoint, keeping the legacy path for back-compat.
  - [ ] App: add load-older-on-scroll to the 1:1 inbox, mirroring the group inbox.
  - [ ] Preserve the optimistic-insert and patent-flow contracts on the 1:1 inbox.
- **Testing:**
  - [ ] Backend **Feature** tests: cursor paging, `limit` clamp, `hasMore`, empty
        and boundary pages.
  - [ ] Backend **Contract** test: the 1:1 conversation response shape (extended,
        not broken) — this is an API-shape change → **app-first release**.
  - [ ] App tests: load-older appends correctly; no duplicate/oldest-first bugs.
  - [ ] **Patent-flow harness stays green** (1:1 inbox hosts the flow).
- **Risk:** medium — touches the patent-hosting screen and an API shape. Handle as
  its own PR with the full patent regression run + a staging build for on-device
  confirmation.

---

### P3 — Guarantee MP4 faststart on sent video  *(Tier 0.3)* **[NEW / improves today's compress-on-send]**
- **Goal:** ensure sent videos start on first bytes (moov atom at front).
- **Expectation:** faster video first-frame (`media_load_ms` for video) on top of
  the size cut we already ship; faststart present on new uploads.
- **To-dos:**
  - [ ] Verify whether `video_compress` output is already faststart (device/tool
        check of the moov position).
  - [ ] If not: add a fast **remux** (`-c copy -movflags +faststart`, no re-encode)
        — client post-compress, or a backend queued job. Keep it fail-safe (fall
        back to the original on error, like the compressor).
  - [ ] Decide whether to backfill existing files (optional).
- **Testing:**
  - [ ] Unit test around the remux decision/seam (fail-safe path returns original).
  - [ ] On-device: confirm a fresh sent video starts faster.
- **Risk:** low-medium — touches the send path we just changed (not the patent
  path). Fail-safe by design.

---

### P4 — Decode-downscale audit  *(Tier 0.4)* **[PARTLY DONE → close gaps]**
- **Goal:** `memCacheWidth/Height = logicalWidth × devicePixelRatio` on **every**
  image slot (avatars, media-picker grid, previews), not just chat bubbles.
- **Expectation:** lower image memory → fewer OOM/jank events in media-heavy
  scroll; `frame_jank` down on those screens.
- **To-dos:**
  - [ ] Audit all `CachedNetworkImage`/`Image` usages for a missing decode size.
  - [ ] Add `memCacheWidth/Height` where absent.
- **Testing:**
  - [ ] Where feasible, widget tests asserting the decode size is set; otherwise a
        documented audit checklist + `flutter analyze`.
- **Risk:** low. Watch for under-sizing (visible softness) — size to DPR, not
  below.

---

### P5 — ThumbHash / BlurHash placeholders  *(Tier 1.1)* **[PLANNED — Branch 2.1]**
- **Goal:** never show a blank media box; a precomputed blur renders instantly.
- **Expectation:** perceived-instant media even on slow links; near-zero extra
  bandwidth (~21-byte hash). Real `media_load_ms` unchanged, but *felt* latency
  drops a lot.
- **To-dos:**
  - [ ] Backend: compute the hash at upload (PHP ThumbHash/BlurHash), migration to
        store it on the message/media row, return it in the payload.
  - [ ] App: render the hash as the `cached_network_image` placeholder
        (`fast_thumbhash`).
- **Testing:**
  - [ ] Backend: unit (hash from a fixture image) + **Contract** test (hash field
        present in the response shape) → API-shape change, app-first.
  - [ ] App: widget test — placeholder decodes from a hash and is replaced by the
        image on load; empty/malformed hash falls back safely.
  - [ ] Migration test (backend migration suite).
- **Risk:** medium — new column + response-shape change (contract test + app-first)
  and a new backend dependency.

---

### P6 — Server-side image variants + WebP  *(Tier 1.2)* **[PLANNED — Branch 2.5]**
- **Goal:** never ship a full-res original into a thumbnail slot.
- **Expectation:** list/grid image bytes drop to a fraction; image `media_load_ms`
  p90 moves toward target.
- **To-dos:**
  - [ ] Backend: generate 2–3 sized variants (thumbnail/feed/full) at upload
        (`intervention/image` or a queued job); serve WebP where `Accept` allows.
  - [ ] App: request the size that fits the slot.
- **Testing:**
  - [ ] Backend: variants generated + stored + served (Feature test); WebP
        negotiation.
  - [ ] App: correct variant URL per slot.
- **Risk:** medium — adds a processing step and storage; keep originals for full
  view. Image-only (video ABR is out of scope — no transcoding pipeline).

---

### P7 — Validate & enable native HTTP/3 client  *(Tier 1.3)* **[DONE-but-OFF]**
- **Goal:** turn on the `native_dio_adapter` (HTTP/3 on iOS) behind
  `Flags.nativeHttp`.
- **Expectation:** connection reuse / fewer handshakes — **but only pays off once
  the server/edge speaks HTTP/3** (P8). Validate on staging first.
- **To-dos:**
  - [ ] Enable the flag on a staging build; compare `media_load_ms`/`api_request`
        latency vs baseline.
  - [ ] Promote the flag only if staging shows a win and no regressions.
- **Testing:** staging A/B via the flag; existing network-layer tests stay green.
- **Risk:** low-medium — depends on P8 to matter; gated behind a flag so easy to
  revert.

---

### P8 — DNS / CDN / object storage  *(Tier 2)* **[DECISION GATE — parked]**
- **Goal:** edge (Cloudflare / Bunny EU) in front of **sent** media → QUIC/HTTP3,
  0-RTT, anycast, byte-range, cache headers at the edge; optionally object storage
  (`league/flysystem-aws-s3-v3` already present).
- **Expectation (ceiling, platform-dependent):** ~20 % fewer video stalls, up to
  ~22 % better rebuffering (Facebook's QUIC numbers); big first-connection win for
  returning users.
- **This is NOT scheduled here.** It's an infra + **legal** decision for Achia:
  - [ ] Provide/confirm the existing "DNS plan" the brief references.
  - [ ] Decide: Cloudflare-proxy quick win vs object-storage+CDN; provider (EU
        residency matters).
  - [ ] Engage counsel for DPA/DPIA **before** any path that could touch reaction
        media. **Reaction faces stay on the EU origin** regardless.
- **Testing:** defined when scoped. **Do not implement without Achia + the privacy
  gate.**

---

### Tier 3 — Backlog (not scheduled; pull in if data justifies)
- Cold-start: run independent blocking inits concurrently (`Future.wait` for
  Firebase/GetStorage/AuthToken); move heavy JSON parse off-isolate (`compute`).
- Backend response caching for hot read endpoints (a `cache` table exists) — only
  if `api_request` latency shows a hotspot.
- TikTok-style bounded player pool + first-frame prebuffer — **only if** a
  reels/swipe feed is added; chat is not a swipe feed. Tune prefetch depth against
  analytics (the "500KB/2s" figure was research-refuted — don't hard-code it).

---

## 3. Testing strategy (cross-cutting)

- **Unit / Feature / Contract** tests wired into the required CI checks
  (`PHP Tests`, `Analyze & Test`) — no phase merges without them.
- **Contract tests** updated for every response-shape change (P2, P5, P6) →
  triggers **app-first** ordering.
- **Patent-flow harness** green on any phase touching the inbox screens (P2 above
  all).
- **Staging TestFlight build** after each user-facing phase for on-device
  confirmation; the **nightly** suite (shipped today) catches drift.
- **Perf digest** before/after per phase against the P0 baseline.

## 4. Sequencing & checkpoints

1. P0 baseline → **STOP** (confirm numbers + read-only key).
2. P1 + P4 (cheap, low-risk, no API shape) → one or two PRs → STOP.
3. P3 (faststart) → PR → staging verify → STOP.
4. P2 (1:1 pagination — biggest, patent-adjacent, API-shape) → its own PR +
   full regression + app-first → STOP.
5. P5 → P6 (perceived-instant look) → STOP between.
6. P8 decision-gate (Achia + legal); P7 follows once the edge speaks HTTP/3.

Nothing here is built until you approve this plan and pick the starting phase.

---

## 5. Open decisions for Achia
- [ ] Provide `POSTHOG_READONLY_KEY` for P0 baselines (or accept dashboard-only)?
- [ ] Where's the existing DNS plan (unblocks P8 scoping)?
- [ ] Appetite for counsel/DPA now (unblocks CDN), or cheap wins first (P1–P6)?
- [ ] Start order — recommend P1+P4 first (safest), then P3, then P2.
