# BRIEF — DNS + media performance (CDN)

**Date:** 2026-07-01
**Author:** Achia (goal) + Claude (findings + research plan)
**Status:** Research / decision brief. Partly blocked: the "DNS plan already made up"
that Achia referenced is **not in the repo** — we need it before finalising.
**Covers:** feature-list item **5a** — "we already have a DNS plan; implement it to get
faster app performance." (The consent half of item 5 is a separate doc:
`docs/BRIEF-recording-consent-at-signup-2026-07-01.md`.)

---

## 1. Important discrepancy to resolve first

Achia said "we have a DNS plan already made up." **A dedicated DNS/CDN plan does not
exist in the repo.** The only DNS content found is the **staging** A-record setup in
`docs/PLAN-staging-and-testing-2026-05-24.md` (Phase 2: `staging.reacti.io →
72.61.202.136` + Let's Encrypt). No CDN, SPF/DKIM/DMARC, or performance-DNS plan is
written down anywhere.

**Action:** Achia to share the DNS plan (a note, a doc elsewhere, or a verbal one) so we
don't duplicate or contradict it. If it only exists informally, this brief becomes the
place to capture it.

---

## 2. What "DNS for faster performance" most likely means

DNS resolution itself is not the app's bottleneck. The real performance lever that DNS
*enables* is a **CDN in front of media**. From project memory + infra docs:

- Media (~**1.6 GB**) is served straight off the **Hostinger VPS local disk**
  (`public/uploads/...` via `backend/app/Helpers/Helper.php`), single-region, no edge
  caching. Every image/video is a round-trip to one box.
- There is **no CDN** today. Adding one (which is largely a DNS + origin-config task)
  is the biggest available media-speed win.

So this item overlaps heavily with the **already-approved**
`docs/PLAN-media-timing-and-speed-2026-06-23.md`, whose **Phase 4** is exactly
"CDN for sent media" + "object storage," but is **gated on a privacy/legal DPA/DPIA**
because reaction media contains real faces. **This brief should be executed as / merged
into that Phase 4 — not as a parallel effort.** Re-read that plan's Phase 4 and §5
before doing anything here.

---

## 3. The privacy split that shapes everything (do not skip)

`PLAN-media-timing-and-speed` §Phase 4 already establishes the rule, and it governs
this work:

- **Sent media** (photos/videos a user chose to send) = lower privacy risk → **safe to
  put behind a CDN first.**
- **Reaction media** (silently recorded faces) = high sensitivity → **stays on the EU
  origin** until counsel signs a DPA + DPIA, short retention, deletion, SCCs for any
  non-EEA transfer. Do **not** route reaction media through a third-party CDN as part of
  a "performance" change.

Any CDN work must keep these two media classes on separate paths.

---

## 4. How to research / decide

### 4.1 Measure the "before" (don't optimise blind)

- Use the **existing media-timing instrumentation** (`media_load_ms`, dashboards from
  `PLAN-media-timing-and-speed` Phase 0) to record current p50/p90 for image and video
  load, split by network. This is the baseline the CDN must beat.
- Inspect current media responses: are **cache headers** (`Cache-Control`, `ETag`) set?
  Often the cheapest win (weeks of caching on immutable media) is a header change, no
  CDN at all. Check `Helper.php`'s upload/serve path.
- Check TTFB from a couple of regions (Reacti has Hebrew/EU users; origin is where?).

### 4.2 Choose the CDN approach

Two options, from the sibling plan:

- **Cloudflare proxy in front of `reacti.io`** — quickest: point the media hostname's
  DNS through Cloudflare (orange-cloud), set cache rules for `/uploads/*`. Free tier
  exists. Minimal migration. Good first step for **sent** media.
- **Object storage + CDN** (`league/flysystem-aws-s3-v3` is **already** in
  `composer.json`) — move `public/uploads` to R2/S3 + edge CDN. Bigger migration
  (URL rewriting, back-compat for existing media URLs), better long-term, and it lines
  up with the AWS/GCP migration idea in project memory. This is `PLAN-media-timing`
  Branch 4.2.
- Sibling plan's provider lean: **Bunny.net (EU-native)** vs **Cloudflare (free +
  R2)** — decide with the privacy constraints in mind (EU residency for anything that
  could ever touch reaction media).

### 4.3 Fold in the other DNS chores while the zone is open

Touch the `reacti.io` DNS zone **once** and do all of it:

- **Email auth records** (SPF/DKIM/DMARC) for the OTP fix —
  `docs/BRIEF-otp-sender-and-email-deliverability-2026-07-01.md`.
- **Consolidate the Reverb websocket host** off `climbiq-goonclimbers.com` onto a clean
  `reacti.io` subdomain (e.g. `ws.reacti.io` / `realtime.reacti.io`). This is a tidy-up
  that also removes the "why is my app talking to goonclimbers.com" oddity. Note: this
  touches the app's realtime config (`--dart-define` per memory) and is an app-then-
  backend, backwards-compatible change — plan it carefully, not as a throwaway.
- Confirm `staging.reacti.io` and any other records are correct.

---

## 5. Deliverables of this research

1. The **baseline** media-load numbers + a check of current cache headers.
2. A **decision**: Cloudflare-proxy quick win vs object-storage+CDN, and the provider.
3. A consolidated **DNS record plan** for `reacti.io` (media/CDN + email auth + realtime
   subdomain + staging), reviewed against Achia's existing DNS plan once shared.
4. Execution folded into **`PLAN-media-timing-and-speed` Phase 4** (with its
   privacy/legal gate), not a separate track.

---

## 6. Open questions for Achia

- **Where is the existing DNS plan?** (blocks finalising this).
- Is there appetite to engage **counsel for the DPA/DPIA** now (unblocks the CDN), or
  do we start with the **cheap, no-legal wins** first: cache headers + Cloudflare proxy
  on **sent** media only, leaving reaction media untouched?
- Consolidate realtime onto `reacti.io` now, or leave `climbiq-goonclimbers.com` alone
  to avoid touching the live realtime path?

---

## 7. Key files / references

- `backend/app/Helpers/Helper.php` — `uploadImage()`/`fileUpload()` → `public/uploads/`
  (media origin; cache-header + storage-driver target).
- `backend/composer.json` — `league/flysystem-aws-s3-v3` present (object storage ready).
- `docs/PLAN-media-timing-and-speed-2026-06-23.md` — **Phase 4** (CDN + object storage)
  and §5 (what not to do); this brief is that phase's DNS/infra companion.
- `docs/PLAN-staging-and-testing-2026-05-24.md` — the only existing DNS (staging).
- `docs/hostinger-deploy-setup.md` — VPS/domain facts.
- Related: `docs/BRIEF-otp-sender-and-email-deliverability-2026-07-01.md` (same DNS zone).
