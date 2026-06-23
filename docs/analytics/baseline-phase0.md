# Phase-0 analytics baseline (PRELIMINARY)

> ⚠️ **Not the locked baseline.** This is a Phase-0 smoke snapshot: image-only,
> small sample (n≈38–39), and the overlap/recording metric is still being
> validated (`overlap_pct > 100` outliers present — see caveats). Do not treat
> these as targets or regression thresholds. Replace with a fuller pull once
> video + cellular samples exist.

- **Pulled:** 2026-06-23, staging only (`analytics_env=staging`)
- **Window:** trailing 30 days
- **Source:** PostHog EU, project `202061`, dashboards
  [755234 — Media load latency] and [755235 — Reaction-media overlap authenticity]
- **Method:** dashboards had never been refreshed; numbers below are overall
  aggregates computed via HogQL over the window (the dashboard tiles were also
  force-refreshed at pull time). Metric definitions: `event-catalog.md`.

## 755234 — Media load latency

| Metric | Value | n |
|---|---|---|
| `media_loaded` events | 39 (all `media_kind=image`) | 39 |
| `media_load_ms` p50 / p90 | 472 / 1236 ms (avg 666) | 39 |
| `media_load_ms` p90 by kind | image 1236 ms (only kind present) | 39 |
| video `media_load_ms` | _no samples — TODO_ | 0 |

## 755235 — Reaction-media overlap authenticity

| Metric | Value | n |
|---|---|---|
| `media_exposure_ms` p50 / p90 | 12,230 / 34,369 ms | 39 |
| `recording_start_offset_ms` avg / p50 | −686 / −575 ms | 38 |
| `overlap_pct` avg / p50 | 83.6% / 86.5% | 38 |
| `overlap_pct` distribution | 100–109:10, 70–79:9, 80–89:8, 90–99:8, then 0–9 / 20–29 / 60–69: 1 each | 38 |

Negative `recording_start_offset_ms` = recording fires before media load completes.

## Caveats

- **Thin sample** (n≈38–39) — fine as a smoke baseline, weak for p90 stability.
- **Image-only** — zero video `media_loaded`; video load latency unmeasured.
- **`overlap_pct > 100`** — 10 events in the 100–109 bucket (recording outlasting
  media exposure). Flag if unexpected; metric still being fixed.

## TODO before this becomes the locked baseline

- [ ] Add **video** `media_load_ms` / `media_loaded` numbers (currently 0 samples).
- [ ] Add **cellular** breakdown (this pull is not segmented by `network_type`).
- [ ] Resolve `overlap_pct > 100` outliers, then re-pull.
- [ ] Grow `n` (exercise the staging flow more) before trusting percentiles.
