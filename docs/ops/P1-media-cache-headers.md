# P1 — Immutable cache headers on media (operator action)

**Plan:** phase P1 of `docs/PLAN-media-performance-2026-07-06.md`.
**Why this is a doc, not a PR:** media under `public/uploads/` is served as
**static files by nginx** (CloudPanel-managed vhost), bypassing Laravel — so the
cache headers must be set in the **nginx vhost**, which is the operator/CloudPanel
lane, not the repo. This note gives the exact change + how to verify.

## What it does
Uploaded media files are **immutable** (each upload gets a unique filename). Today
they're served with no `Cache-Control`, so a client re-downloads the same
image/video every time it re-appears. Adding a long-lived immutable cache header
makes each file download **once per device**, then serve instantly from cache.

**Expected win:** repeat-view `media_load_ms` drops toward ≈ 0; origin egress and
re-open latency fall sharply. No effect on first view. Zero risk to correctness
(filenames are unique, so "cache forever" is safe).

## The change (CloudPanel → Sites → reacti.io → Vhost / "Nginx directives")
Add a location block for the uploads path:

```nginx
location /uploads/ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable" always;
    # Static files already send ETag + Accept-Ranges (byte-range) by default;
    # do NOT gzip already-compressed media (images/video).
    access_log off;
}
```

Notes:
- Apply on **both** production (`reacti.io`) and staging (`staging.reacti.io`) so
  the staging perf digest reflects it.
- This covers **sent** media and reaction media alike at the header level — it
  changes caching only, not where files are stored, so the reaction-media / EU-
  origin privacy split is unaffected (that split is about CDN routing, a separate
  decision in plan P8). Cache headers on the origin are fine for both.
- If uploads live under a subpath (e.g. `/storage/uploads/` or a symlinked
  `public/uploads`), match that exact prefix.

## How to verify
After applying, from any machine:

```sh
curl -sI https://staging.reacti.io/uploads/<some-existing-file>.jpg | grep -i 'cache-control\|etag\|accept-ranges'
```

Expect:
```
Cache-Control: public, max-age=31536000, immutable
ETag: "..."
Accept-Ranges: bytes
```

Then re-open a chat with media in the app twice — the second open should be
instant (served from the device cache), and `media_load_ms` for that media on the
staging dashboard should drop on the repeat.

## Rollback
Remove the `location /uploads/` block and reload nginx. No data is touched.
