#!/usr/bin/env python3
"""Pull a compact performance digest from PostHog (read-only).

Queries the new perf/UX metrics for a given ``analytics_env`` and time window
and prints a one-screen digest: media-load p50/p90, reaction-media overlap_pct
average (the authenticity signal), screen-render p90, frame-jank totals, API
latency p90, and cold-start p90 — each with its sample size.

Below that it splits smoothness and cold start by operating system and by
phone model (one cheap phone must not hide inside an average, and one odd
device must not skew it), and, when a Sentry read token is present, lists the
top errors and says which of them were real crashes.

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
    SENTRY_READ_TOKEN      (optional) read-only Sentry token; without it the
                           "top errors" section is skipped.

Exit codes: 0 ok; 2 missing key; 1 API/query error.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_HOST = "https://eu.posthog.com"
DEFAULT_PROJECT = "202061"
# The app's Sentry project (EU region); read through the events endpoint.
SENTRY_EVENTS_URL = "https://de.sentry.io/api/0/organizations/reacti/events/"
SENTRY_APP_PROJECT = "4511565805256784"

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


# How Sentry labels a Dart error the app survived (it kept running). SDK 9
# still marks the session "crashed" for these, which is why its crash-free
# figure looks worse than reality. Any other unhandled mechanism (mach,
# signalhandler, an ANR) is a real crash. An unlisted name reads as a crash on
# purpose: a false alarm gets looked at, a hidden crash does not.
SURVIVED_MECHANISMS = {"PlatformDispatcher.onError", "FlutterError"}

# Every frame drawn: the reported windows plus the smooth ones in between.
_FRAMES = ("toFloat(properties.frame_count)"
           " + ifNull(toFloat(properties.quiet_frame_count), 0)")
# Events from app versions that measure build and raster separately.
_SPLIT = "event='frame_jank' and properties.refresh_hz is not null"

DEVICE_HEADER = (
    f"  {'os':<8} {'model':<14} {'people':>6} {'frames':>10} {'>16ms':>7}"
    f" {'slow build':>10} {'slow draw':>9} {'worst p90':>9}"
    f" {'cold p50':>8} {'cold p90':>8}"
)


def build_device_query(env: str, days: int, by_model: bool) -> str:
    """Builds the per-OS (or per-OS-and-phone-model) smoothness/cold-start rows.

    Columns: os, model, people, frames, frames over the fixed 16 ms, frames of
    the versions that split build/raster, slow builds, slow rasters, worst
    frame p90, cold start p50, cold start p90.
    """
    model = "properties.$device_model" if by_model else "'all'"
    cold = ("if(event='app_open' and properties.is_cold_start,"
            " toFloat(properties.cold_start_ms), null)")
    # env is validated to an enum by argparse, so it is safe to inline.
    return (
        "select properties.$os as os,\n"
        f"  {model} as model,\n"
        "  uniq(person_id) as people,\n"
        f"  sum(if(event='frame_jank', {_FRAMES}, 0)) as frames,\n"
        "  sum(if(event='frame_jank', toFloat(properties.jank_frame_count), 0))"
        " as over16,\n"
        f"  sum(if({_SPLIT}, {_FRAMES}, 0)) as split_frames,\n"
        f"  sum(if({_SPLIT}, toFloat(properties.slow_build_count), 0))"
        " as slow_build,\n"
        f"  sum(if({_SPLIT}, toFloat(properties.slow_raster_count), 0))"
        " as slow_raster,\n"
        "  quantile(0.9)(if(event='frame_jank', toFloat(properties.jank_max_ms),"
        " null)) as worst_p90,\n"
        f"  quantile(0.5)({cold}) as cold_p50,\n"
        f"  quantile(0.9)({cold}) as cold_p90\n"
        "from events\n"
        f"where properties.analytics_env = '{env}'\n"
        f"  and timestamp >= now() - toIntervalDay({days})\n"
        "  and event in ('frame_jank', 'app_open')\n"
        "group by os, model\n"
        "order by os, frames desc\n"
        "limit 60"
    )


def pct(part, whole) -> str:
    """Formats part/whole as a percentage, or 'n/a' with nothing to divide by."""
    if not whole:
        return "n/a"
    return f"{100 * float(part or 0) / float(whole):.1f}%"


def device_line(row) -> str:
    """Formats one row of ``build_device_query`` as a fixed-width report line."""
    (os_name, model, people, frames, over16, split_frames, slow_build,
     slow_raster, worst_p90, cold_p50, cold_p90) = row
    return (
        f"  {str(os_name or '?'):<8} {str(model or '?'):<14} {people:>6}"
        f" {fmt(frames):>10} {pct(over16, frames):>7}"
        f" {pct(slow_build, split_frames):>10}"
        f" {pct(slow_raster, split_frames):>9}"
        f" {fmt(worst_p90):>9} {fmt(cold_p50):>8} {fmt(cold_p90):>8}"
    )


def is_real_crash(mechanisms, handled) -> bool:
    """Whether a Sentry error row is a real crash, not an error the app survived.

    ``mechanisms`` is the row's ``error.mechanism`` list, ``handled`` its
    ``error.handled`` (0 = unhandled).
    """
    if handled:
        return False
    reported_by = set(mechanisms or [])
    return not reported_by or not reported_by <= SURVIVED_MECHANISMS


def fetch_top_errors(token: str, env: str, days: int):
    """Reads the top error titles from Sentry (read-only) as a list of rows."""
    fields = ["title", "os.name", "error.handled", "error.mechanism",
              "count()", "count_unique(user)"]
    params = [("dataset", "errors"), ("project", SENTRY_APP_PROJECT),
              ("environment", env), ("statsPeriod", f"{days}d"),
              ("sort", "-count()"), ("per_page", "15")]
    params += [("field", f) for f in fields]
    req = urllib.request.Request(
        f"{SENTRY_EVENTS_URL}?{urllib.parse.urlencode(params)}",
        headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp).get("data") or []


def error_line(row) -> str:
    """Formats one Sentry error row: verdict, OS, events, people, title."""
    crash = is_real_crash(row.get("error.mechanism"), row.get("error.handled"))
    verdict = "CRASH" if crash else "kept running"
    return (f"  {verdict:<12} {str(row.get('os.name') or '?'):<8}"
            f" {row.get('count()', 0):>6} {row.get('count_unique(user)', 0):>6}"
            f"  {str(row.get('title') or '')[:70]}")


def print_devices(host: str, project: str, key: str, env: str, days: int):
    """Prints the smoothness/cold-start split by OS, then by phone model."""
    for title, by_model in (("By operating system", False),
                            ("By phone model", True)):
        result = run_query(host, project, key,
                           build_device_query(env, days, by_model))
        print(f"\n{title}")
        print(DEVICE_HEADER)
        for row in result.get("results") or []:
            print(device_line(row))
    print("  frames: every frame drawn, once the app version reports quiet"
          " windows.\n  slow build / slow draw: n/a before the app version"
          " that measures them.")


def print_top_errors(env: str, days: int):
    """Prints Sentry's top errors, or why the section was skipped."""
    print("\nTop errors (Sentry)")
    token = os.environ.get("SENTRY_READ_TOKEN", "").strip()
    if not token:
        print("  skipped: SENTRY_READ_TOKEN is not set.")
        return
    errors = fetch_top_errors(token, env, days)
    print(f"  {'verdict':<12} {'os':<8} {'events':>6} {'people':>6}  title")
    for row in errors:
        print(error_line(row))
    crashes = sum(1 for r in errors if is_real_crash(
        r.get("error.mechanism"), r.get("error.handled")))
    print(f"  {crashes} of {len(errors)} rows are real crashes;"
          " the rest left the app running.")


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

    try:
        print_devices(host, project, key, args.env, args.days)
        print_top_errors(args.env, args.days)
    except urllib.error.URLError as e:
        print(f"error: device or error section failed: {e}", file=sys.stderr)
        return 1

    print("\nread-only; metadata only; no PII."
          " See docs/analytics/perf-workflow.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
