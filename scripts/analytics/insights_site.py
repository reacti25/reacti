"""Build the "Reacti Insights" website: one self-contained HTML page with the
production analytics, regenerated daily by .github/workflows/insights-site.yml
and published to Cloudflare Pages.

Read-only. Pulls aggregates from PostHog (never an individual, never media) and
renders them into scripts/analytics/insights_template.html.

Usage:
    POSTHOG_READONLY_KEY=phx_... python scripts/analytics/insights_site.py --out site/index.html

Env:
    POSTHOG_READONLY_KEY  (required) read-only personal API key.
    POSTHOG_HOST          default https://eu.posthog.com
    POSTHOG_PROJECT_ID    default 202061
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

HOST = os.environ.get("POSTHOG_HOST", "https://eu.posthog.com").rstrip("/")
PROJECT = os.environ.get("POSTHOG_PROJECT_ID", "202061")
PROD = [{"type": "event", "key": "analytics_env", "value": ["production"], "operator": "exact"}]
TEMPLATE = Path(__file__).with_name("insights_template.html")


# --- PostHog -----------------------------------------------------------------

def query(key: str, source: dict) -> dict:
    """Run one PostHog query (Trends/Funnels/Retention/HogQL) and return its JSON."""
    req = urllib.request.Request(
        f"{HOST}/api/projects/{PROJECT}/query/",
        data=json.dumps({"query": source}).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise SystemExit(f"PostHog query failed ({e.code}): {e.read().decode()[:300]}")


def hogql(key: str, sql: str) -> list:
    return query(key, {"kind": "HogQLQuery", "query": sql})["results"]


def ev(event: str, math: str = "total", props: list | None = None, **extra) -> dict:
    node = {"kind": "EventsNode", "event": event, "math": math, **extra}
    if props:
        node["properties"] = props
    return node


def prop(k: str, v: str) -> dict:
    return {"type": "event", "key": k, "value": [v], "operator": "exact"}


SUCCESS = [prop("result", "success")]
MEDIA = [prop("message_type", "media")]
ENV = "properties.analytics_env = 'production'"


# --- Metrics -----------------------------------------------------------------

def kpi(key: str, event: str, days: int, where: str = "", distinct: bool = False) -> dict:
    """Value for the last `days` and the `days` before, for a headline card."""
    agg = "count(DISTINCT distinct_id)" if distinct else "count()"
    extra = f" AND {where}" if where else ""
    sql = (
        f"SELECT {agg} FROM events WHERE event = '{event}' AND {ENV}{extra} "
        f"AND timestamp > now() - INTERVAL {days} DAY"
    )
    prev = (
        f"SELECT {agg} FROM events WHERE event = '{event}' AND {ENV}{extra} "
        f"AND timestamp > now() - INTERVAL {2 * days} DAY AND timestamp <= now() - INTERVAL {days} DAY"
    )
    now_v, prev_v = hogql(key, sql)[0][0], hogql(key, prev)[0][0]
    return {"value": now_v, "previous": prev_v}


def daily(key: str, series: list[tuple[str, str, str]], days: int = 60) -> dict:
    """Per-day counts for several (label, event, where) series, zero-filled."""
    today = dt.date.today()
    labels = [(today - dt.timedelta(days=d)).isoformat() for d in range(days - 1, -1, -1)]
    out = {"labels": labels, "series": []}
    for label, event, where, distinct in series:
        agg = "count(DISTINCT distinct_id)" if distinct else "count()"
        extra = f" AND {where}" if where else ""
        rows = hogql(key, (
            f"SELECT toDate(timestamp) AS d, {agg} FROM events WHERE event = '{event}' AND {ENV}{extra} "
            f"AND timestamp > now() - INTERVAL {days} DAY GROUP BY d ORDER BY d"
        ))
        by_day = {str(d): n for d, n in rows}
        out["series"].append({"label": label, "data": [by_day.get(day, 0) for day in labels]})
    return out


def breakdown(key: str, event: str, prop_name: str, days: int = 60, where: str = "", distinct: bool = True, limit: int = 8) -> list:
    agg = "count(DISTINCT distinct_id)" if distinct else "count()"
    extra = f" AND {where}" if where else ""
    rows = hogql(key, (
        f"SELECT coalesce(toString(properties.{prop_name}), 'unknown') AS k, {agg} AS n FROM events "
        f"WHERE event = '{event}' AND {ENV}{extra} AND timestamp > now() - INTERVAL {days} DAY "
        f"GROUP BY k ORDER BY n DESC LIMIT {limit}"
    ))
    return [{"label": k, "value": n} for k, n in rows]


def loop_funnel(key: str) -> list:
    """People reaching each step of the Reacti loop in the last 90 days.

    Counted per step, not as one ordered journey: the live app (1.6.0)
    changes a person's analytics id at sign-up, so an ordered funnel loses
    everyone at that step. The fix (PR #454) ships with the next app update;
    switch this to an ordered FunnelsQuery once most users run it.
    """
    steps = [
        ("Signed up", "signup_completed"),
        ("Finished the demo", "demo_reaction_completed"),
        ("Sent a first Reacti", "first_message_sent"),
        ("Got a first reaction back", "first_reaction_received"),
    ]
    out = []
    for label, event in steps:
        n = hogql(key, (
            f"SELECT count(DISTINCT distinct_id) FROM events WHERE event = '{event}' AND {ENV} "
            f"AND timestamp > now() - INTERVAL 90 DAY"
        ))[0][0]
        out.append({"label": label, "value": n})
    return out


def retention(key: str) -> list:
    """Share of each first-week cohort that opened the app again, week by week."""
    res = query(key, {
        "kind": "RetentionQuery",
        "dateRange": {"date_from": "-56d"},
        "properties": PROD,
        "retentionFilter": {
            "targetEntity": {"id": "app_open", "type": "events"},
            "returningEntity": {"id": "app_open", "type": "events"},
            "period": "Week", "totalIntervals": 8, "retentionType": "retention_first_time",
        },
    })["results"]
    rows = []
    for cohort in res:
        values = [v["count"] for v in cohort["values"]]
        if values and values[0]:
            # PostHog labels cohorts "Week 0..n"; the start date reads better.
            start = dt.date.fromisoformat(str(cohort.get("date", ""))[:10]) if cohort.get("date") else None
            label = f"{start.day} {start:%b}" if start else cohort["label"]
            rows.append({"cohort": label, "size": values[0],
                         "pct": [round(100 * v / values[0]) for v in values]})
    return rows


def median_seconds(key: str, event: str, prop_name: str, days: int = 30, where: str = "") -> float | None:
    extra = f" AND {where}" if where else ""
    v = hogql(key, (
        f"SELECT quantile(0.5)(toFloat(properties.{prop_name})) FROM events WHERE event = '{event}' "
        f"AND {ENV}{extra} AND timestamp > now() - INTERVAL {days} DAY"
    ))[0][0]
    return round(v / 1000, 1) if v is not None else None


def collect(key: str) -> dict:
    media_ok = "properties.message_type = 'media' AND properties.result = 'success'"
    ok = "properties.result = 'success'"
    data = {
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%d %b %Y, %H:%M UTC"),
        "kpis": {
            "active_7d": kpi(key, "app_open", 7, distinct=True),
            "active_30d": kpi(key, "app_open", 30, distinct=True),
            "signups_30d": kpi(key, "signup_completed", 30),
            "reactis_30d": kpi(key, "message_sent", 30, media_ok),
            "reactions_30d": kpi(key, "reaction_sent", 30, ok),
            "messages_30d": kpi(key, "message_sent", 30, ok),
        },
        "active_daily": daily(key, [("Active users", "app_open", "", True)]),
        "loop_daily": daily(key, [
            ("Reactis sent", "message_sent", media_ok, False),
            ("Reactions captured", "reaction_sent", ok, False),
        ]),
        "funnel": loop_funnel(key),
        "retention": retention(key),
        "countries": breakdown(key, "app_open", "country"),
        "platforms": breakdown(key, "app_open", "platform"),
        "versions": breakdown(key, "app_open", "app_version", days=30),
        "message_types": breakdown(key, "message_sent", "message_type", where=ok, distinct=False),
        "invites": {
            "shared": hogql(key, f"SELECT count() FROM events WHERE event='invite_shared' AND {ENV} AND timestamp > now() - INTERVAL 60 DAY")[0][0],
            "opened": hogql(key, f"SELECT count() FROM events WHERE event='invite_opened' AND {ENV} AND timestamp > now() - INTERVAL 60 DAY")[0][0],
            "connected": hogql(key, f"SELECT count() FROM events WHERE event='invite_connected' AND {ENV} AND timestamp > now() - INTERVAL 60 DAY")[0][0],
        },
        "failed_reactions": breakdown(key, "reaction_recorded", "failure_reason", where="properties.result = 'failure'", distinct=False),
        "logins": breakdown(key, "login_result", "result", distinct=False),
        "session_median_s": median_seconds(key, "session_end", "elapsed_ms"),
        "permissions": [
            {"label": p, "granted": g, "asked": a}
            for p, g, a in hogql(key, (
                f"SELECT properties.permission AS p, countIf(properties.result = 'granted') AS g, count() AS a "
                f"FROM events WHERE event = 'permission_result' AND {ENV} AND timestamp > now() - INTERVAL 60 DAY "
                f"GROUP BY p ORDER BY a DESC"
            ))
        ],
    }
    data["insights"] = insights(data)
    return data


# --- Plain-language insights ---------------------------------------------------

def pct(a: float, b: float) -> int:
    return round(100 * a / b) if b else 0


def insights(d: dict) -> list[str]:
    """A few plain sentences about what stands out, worst problem first."""
    notes = []
    f = {x["label"]: x["value"] for x in d["funnel"]}
    if f.get("Signed up"):
        # ponytail: per-step counts, not the same people; say so plainly until the ordered funnel is back.
        notes.append(f"Last 90 days: {f['Signed up']} sign-ups, and {f['Got a first reaction back']} people got their "
                     f"first reaction back (the moment Reacti makes sense).")
    if f.get("Sent a first Reacti") and f.get("Got a first reaction back") is not None:
        waiting = f["Sent a first Reacti"] - f["Got a first reaction back"]
        if waiting > 0:
            who = "1 person" if waiting == 1 else f"{waiting} people"
            notes.append(f"{who} sent a first Reacti but never got a reaction back. Their friends "
                         f"may not have the app yet, so inviting friends is the lever.")
    logins = {x["label"]: x["value"] for x in d["logins"]}
    total = sum(logins.values())
    if total and logins.get("failure", 0) / total >= 0.2:
        notes.append(f"{pct(logins['failure'], total)}% of sign-in attempts fail. Worth checking the login screen "
                     f"(forgotten passwords, unclear errors).")
    k = d["kpis"]
    if k["reactis_30d"]["value"]:
        notes.append(f"For every Reacti sent, {k['reactions_30d']['value'] / k['reactis_30d']['value']:.1f} reactions "
                     f"came back in the last 30 days.")
    fails = sum(x["value"] for x in d["failed_reactions"])
    if fails:
        top = d["failed_reactions"][0]
        notes.append(f"{fails} reactions failed to record in the last 60 days, most often because of "
                     f"“{top['label']}”. Each one is a lost moment.")
    return notes


# --- Render ------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="site/index.html")
    ap.add_argument("--json", help="also write the raw data here (for debugging)")
    args = ap.parse_args()

    key = os.environ.get("POSTHOG_READONLY_KEY", "").strip()
    if not key:
        print("error: POSTHOG_READONLY_KEY is not set", file=sys.stderr)
        return 2

    data = collect(key)
    html = TEMPLATE.read_text(encoding="utf-8").replace("/*__DATA__*/null", json.dumps(data))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    if args.json:
        Path(args.json).write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"wrote {out} ({len(html) // 1024} KB), data as of {data['generated_at']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
