# scripts/analytics

Read-only analytics tooling. Nothing here writes to PostHog or holds a secret.

## `perf_digest.py`

Prints a compact performance digest (media-load p50/p90, reaction-media
`overlap_pct` average, screen-render p90, frame-jank totals, API latency p90,
cold-start p90) for an `analytics_env` and time window.

```sh
# Read-only key comes from the environment — never the repo.
export POSTHOG_READONLY_KEY=phx_...      # local: your read-only key
python scripts/analytics/perf_digest.py --env staging --days 7
```

Flags:
- `--env staging|production` (default `staging`)
- `--days N` look-back window (default `7`)

Optional env overrides: `POSTHOG_HOST` (default `https://eu.posthog.com`),
`POSTHOG_PROJECT_ID` (default `202061`).

In CI, inject the `POSTHOG_READONLY_KEY` GitHub secret as the env var. Exit
codes: `0` ok, `2` missing key, `1` API/query error.

See **`docs/analytics/perf-workflow.md`** for how to use the digest to actually
improve performance (the measure → locate → fix → re-measure loop, targets, and
the staging-first rule).
