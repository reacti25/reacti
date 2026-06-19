#!/usr/bin/env python3
"""Pull a compact performance digest from PostHog (read-only).

Queries the new perf/UX metrics for a given ``analytics_env`` and time window
and prints a one-screen digest: media-load p50/p90, reaction-media overlap_pct
average (the authenticity signal), screen-render p90, frame-jank totals, API
latency p90, and cold-start p90 — each with its sample size.

Read-only by design: it only issues HogQL ``/query`` reads. **No secret lives in
the repo** — the key is read from the ``POSTHOG_READONLY_KEY`` environment
variable (locally: export it for the shell; in CI: inject the
``POSTHOG_READONLY_KEY`` GitHub secret).

Usage:
    POSTHOG_READONLY_KEY=phx_... python scripts/analytics/perf_digest.py \
        --env staging --days 7

Environment variables:
    POSTHOG_READONLY_KEY   (required) read-only personal API key.
    POSTHOG_HOST           PostHog host (default https://eu.posthog.com).
    POSTHOG_PROJECT_ID     project id (default 202061).

Exit codes: 0 ok; 2 missing key; 1 API/query error.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_HOST = "https://eu.posthog.com"
DEFAULT_PROJECT = "202061"

# Each metric: (label, HogQL expression over `events`, sample-size expression).
# quantile()/avg() ignore NULLs, so per-metric filtering is done with
# if(event=..., value, null); counts use sumIf-style if(...,1,0).
METRICS = [
    ("media_load p50 (ms)",
     "quantile(0.5)(if(event='media_loaded', toFloat(properties.media_load_ms), null))",
     "countIf(event='media_loaded')"),
    ("media_load p90 (ms)",
     "quantile(0.9)(if(event='media_loaded', toFloat(properties.media_load_ms), null))",
     "countIf(event='media_loaded')"),
    ("overlap_pct avg (authenticity)",
     "avg(if(event='recording_media_overlap', toFloat(properties.overlap_pct), null))",
     "countIf(event='recording_media_overlap')"),
    ("screen_render p90 (ms)",
     "quantile(0.9)(if(event='screen_render', toFloat(properties.screen_render_ms), null))",
     "countIf(event='screen_render')"),
    ("frame-jank frames (sum)",
     "sum(if(event='frame_jank', toFloat(properties.jank_frame_count), 0))",
     "countIf(event='frame_jank')"),
    ("frame-jank worst frame (ms)",
     "max(if(event='frame_jank', toFloat(properties.jank_max_ms), 0))",
     "countIf(event='frame_jank')"),
    ("api latency p90 (ms)",
     "quantile(0.9)(if(event='api_request', toFloat(properties.latency_ms), null))",
     "countIf(event='api_request')"),
    ("cold_start p90 (ms)",
     "quantile(0.9)(if(event='app_open', toFloat(properties.cold_start_ms), null))",
     "countIf(event='app_open')"),
]


def build_query(env: str, days: int) -> str:
    """Builds the single HogQL row that computes every metric + its count."""
    cols = []
    for i, (_, value_expr, count_expr) in enumerate(METRICS):
        cols.append(f"{value_expr} as v{i}")
        cols.append(f"{count_expr} as n{i}")
    select = ",\n  ".join(cols)
    # env is validated to an enum below, so it is safe to inline.
    return (
        f"select\n  {select}\n"
        f"from events\n"
        f"where properties.analytics_env = '{env}'\n"
        f"  and timestamp >= now() - toIntervalDay({days})"
    )


def run_query(host: str, project: str, key: str, hogql: str):
    body = json.dumps({"query": {"kind": "HogQLQuery", "query": hogql}}).encode()
    req = urllib.request.Request(
        f"{host}/api/projects/{project}/query/",
        data=body, method="POST",
        headers={"Authorization": f"Bearer {key}",
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def fmt(value) -> str:
    """Formats a numeric metric value, or 'n/a' when there were no samples."""
    if value is None:
        return "n/a"
    return f"{round(float(value)):,}"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="PostHog perf digest (read-only).")
    parser.add_argument("--env", default="staging",
                        choices=["staging", "production"],
                        help="analytics_env to report (default: staging).")
    parser.add_argument("--days", type=int, default=7,
                        help="look-back window in days (default: 7).")
    args = parser.parse_args(argv)

    key = os.environ.get("POSTHOG_READONLY_KEY", "").strip()
    if not key:
        print("error: POSTHOG_READONLY_KEY is not set (read-only key).",
              file=sys.stderr)
        return 2
    host = os.environ.get("POSTHOG_HOST", DEFAULT_HOST).rstrip("/")
    project = os.environ.get("POSTHOG_PROJECT_ID", DEFAULT_PROJECT)

    hogql = build_query(args.env, args.days)
    try:
        result = run_query(host, project, key, hogql)
    except urllib.error.HTTPError as e:
        print(f"error: query failed ({e.code}): {e.read().decode()[:300]}",
              file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"error: could not reach PostHog: {e.reason}", file=sys.stderr)
        return 1

    rows = result.get("results") or []
    if not rows:
        print(f"No data for env={args.env} in the last {args.days}d.")
        return 0
    row = rows[0]

    print(f"PostHog perf digest  |  env={args.env}  |  last {args.days}d")
    print("-" * 52)
    for i, (label, _, _) in enumerate(METRICS):
        value, count = row[i * 2], row[i * 2 + 1]
        print(f"  {label:<32} {fmt(value):>10}   (n={count})")
    print("-" * 52)
    print("read-only; metadata only; no PII. See docs/analytics/perf-workflow.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
