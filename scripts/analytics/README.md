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

## `growth_digest.py`

Prints the growth digest: the activation funnel with time-to-value, the
walkthrough's effect on activation, a country breakdown, what the OS permission
dialogs came back with, sign-ins and the deliberate ways people leave, and
rolling D1/D7/D30 retention.

```sh
export POSTHOG_READONLY_KEY=phx_...
python scripts/analytics/growth_digest.py --env production --days 30
```

Flags:
- `--env staging|production` (default `production`)
- `--days N` look-back window for every section except retention (default
  `30`). Retention uses its own longer cohort window, since a D30 number needs
  people who arrived at least 30 days ago.

Same env overrides and exit codes as `perf_digest.py`.

Self-check (there is no Python job in CI):

```sh
python scripts/analytics/test_growth_digest.py
```

## The invite loop is not here

The public landing page carries no third-party script, so a web visit leaves no
analytics event, only a counter on the `invites` row Reacti already owns. Read
it on the server:

```sh
php artisan invites:digest            # all time
php artisan invites:digest --days=30
```

See **`docs/analytics/growth-workflow.md`** for what each number means and
which question it answers.
