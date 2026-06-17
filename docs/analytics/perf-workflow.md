# Reacti performance-improvement workflow

How we turn the analytics perf/UX metrics into actual speed-ups, without
guessing and without touching production blind. **Staging-first**: measure and
fix against `analytics_env=staging`; production numbers are read-only reference
and only matter after a release is live.

> Metric definitions live in `event-catalog.md`. Privacy rules (metadata only,
> salted ids, no PII) live in `privacy.md`. This doc is the *loop* that uses them.

## The loop

1. **Measure** — pull the current digest for the window you care about:

   ```sh
   export POSTHOG_READONLY_KEY=phx_...          # read-only key (never committed)
   python scripts/analytics/perf_digest.py --env staging --days 7
   ```

   Output is one screen: `media_load` p50/p90, `overlap_pct` avg (authenticity),
   `screen_render` p90, frame-jank totals, `api latency` p90, `cold_start` p90 —
   each with its sample size `n`. Low `n` means the number isn't trustworthy yet;
   exercise the flow more on a staging build before drawing conclusions.

2. **Spot the regression** — compare against the targets below and against the
   trend on the staging dashboards (see *Where the data lives*). A number that
   moved the wrong way week-over-week, or a p90 far above its p50 (a tail
   problem), is the signal.

3. **Locate it** — map the metric to code:
   - `cold_start_ms` → `main.dart` bootstrap (Firebase/GetStorage/DI ordering).
   - `screen_render_ms` (by `screen`) → the offending screen's `build`/first
     frame; look for synchronous work in `initState`/`build`.
   - `media_load_ms` → image decode / network (`InboxCustomNetworkImage`,
     caching, image size).
   - `frame_jank` (by `screen`) → heavy build methods, unbounded lists, large
     images on the UI thread.
   - `api latency p90` → backend endpoint (cross-check the backend
     `api_request` / `message_persisted` metrics and Sentry traces).
   - `overlap_pct` / `recording_start_offset_ms` → the patent path
     (`receiver_message_widget.dart`); a falling `overlap_pct` means reactions
     are increasingly captured *before* the media is actually visible — a media
     load or recording-trigger timing problem.

4. **Fix** — make the change behind tests. If it touches the patent path, the
   change must keep `send → record → reaction` byte-for-byte and the full
   patent-flow harness green (see the clean-code-standards skill). Analytics
   instrumentation itself is always fire-and-forget and must never alter a flow.

5. **Re-measure on staging** — land the fix on `develop`, cut a staging
   TestFlight build, exercise the flow, and re-run the digest. Confirm the
   metric moved and nothing else regressed. Only then is it a real win.

## Targets (rules of thumb, tune as data grows)

| Metric | Good (p90 unless noted) | Investigate above |
|---|---|---|
| `cold_start_ms` | < 1500 | 2500 |
| `screen_render_ms` | < 300 | 600 |
| `media_load_ms` | < 800 | 1500 |
| `api latency` (`latency_ms`) | < 400 | 800 |
| `frame_jank` worst frame | < 100 | 250 |
| `overlap_pct` avg | **> 80** (higher = more authentic) | **below 70** |

`overlap_pct` is the only "higher is better" number: it is the share of the
silent reaction that was captured while the media was actually on screen.

## Where the data lives

PostHog (EU), project `202061`, all insights filtered to `analytics_env`:

- Media load latency — dashboard `755234`
- Reaction-media overlap authenticity — dashboard `755235`
- Screen render / TTI — dashboard `755236`
- Frame jank — dashboard `755237`
- App speed overview (p90 headline numbers) — dashboard `755238`

The digest script is the headless equivalent of the *App speed overview* and is
the right tool for CI checks, before/after comparisons, and quick terminal pulls.

## Guardrails

- **Read-only.** The digest uses `POSTHOG_READONLY_KEY` (a read-only personal
  key, stored as a GitHub secret, never in the repo). It only issues `/query`
  reads — it cannot create or mutate anything.
- **Staging-first.** Validate every fix against `--env staging`. Production
  numbers are reference only; never chase a prod metric with an unverified
  change, and never promote to `main`/deploy to prod to "test" a perf fix.
- **No new metric without the catalog.** Adding a measurement means adding the
  event + allowlisted props to `event-catalog.md` and the typed constants first
  (the allowlist test fails the build otherwise).
