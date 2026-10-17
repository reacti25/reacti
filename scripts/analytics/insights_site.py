"""Build the "Reacti Insights" website: one self-contained HTML page with the
production analytics, rebuilt hourly by .github/workflows/insights-site.yml
and published to Cloudflare Pages.

Read-only. Pulls aggregates from PostHog (and, when configured, App Store
Connect sales reports) and renders them into insights_template.html. The page
never shows an individual, a message or any media.

The metrics follow the frameworks consumer apps are judged by: growth
accounting and the quick ratio (Amplitude, Sequoia), DAU/MAU stickiness and
the power-user curve (a16z), cohort retention, activation / time to value, and
Reacti's own loop (Reacti sent, opened, reaction back).

Usage:
    POSTHOG_READONLY_KEY=phx_... python scripts/analytics/insights_site.py --out site/index.html

Env:
    POSTHOG_READONLY_KEY  (required) read-only personal API key.
    POSTHOG_HOST          default https://eu.posthog.com
    POSTHOG_PROJECT_ID    default 202061
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY, ASC_VENDOR_NUMBER
                          (optional) App Store Connect API key with the Sales
                          (or Admin/Finance) role, for downloads. Skipped when
                          any is missing or the key is refused.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import gzip
import io
import json
import os
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

HOST = os.environ.get("POSTHOG_HOST", "https://eu.posthog.com").rstrip("/")
PROJECT = os.environ.get("POSTHOG_PROJECT_ID", "202061")
TEMPLATE = Path(__file__).with_name("insights_template.html")
ENV = "properties.analytics_env = 'production'"
# ponytail: HogQL caps a result at 50k rows; the activity query returns one row
# per person per active day, so past ~400 daily users move it to a daily rollup.
LIMIT = 50000
DAYS = 90      # length of the daily charts
WEEKS = 12     # length of the weekly charts

# Typical consumer-social retention (rolling), used only as a reference line.
BENCHMARK_RETENTION = {1: 30, 7: 15, 30: 8}


# --- PostHog -----------------------------------------------------------------

def hogql(key: str, sql: str) -> list:
    req = urllib.request.Request(
        f"{HOST}/api/projects/{PROJECT}/query/",
        data=json.dumps({"query": {"kind": "HogQLQuery", "query": sql}}).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read())["results"]
    except urllib.error.HTTPError as e:
        raise SystemExit(f"PostHog query failed ({e.code}): {e.read().decode()[:300]}")


# --- Pure metric maths (tested in test_insights_site.py) ---------------------

def periods(today: dt.date, n: int, length: int = 7) -> list[tuple[dt.date, dt.date]]:
    """n back-to-back periods of `length` days ending today, oldest first."""
    return [(today - dt.timedelta(days=length * (i + 1) - 1), today - dt.timedelta(days=length * i))
            for i in range(n - 1, -1, -1)]


def active_in(activity: dict, start: dt.date, end: dt.date) -> set:
    return {p for p, days in activity.items() if any(start <= d <= end for d in days)}


def growth_accounting(activity: dict, first_seen: dict, today: dt.date, weeks: int = WEEKS) -> list[dict]:
    """Per 7-day period: new, retained, resurrected and churned people + quick ratio."""
    spans = periods(today, weeks + 1)
    out = []
    for (ps, pe), (s, e) in zip(spans, spans[1:]):
        prev, cur = active_in(activity, ps, pe), active_in(activity, s, e)
        new = {p for p in cur if s <= first_seen[p] <= e}
        retained = cur & prev
        resurrected = cur - prev - new
        churned = prev - cur
        out.append({
            "label": f"{s.day} {s:%b}", "active": len(cur), "new": len(new), "retained": len(retained),
            "resurrected": len(resurrected), "churned": len(churned),
            "quick_ratio": round((len(new) + len(resurrected)) / len(churned), 2) if churned else None,
        })
    return out


def daily_active(activity: dict, today: dt.date, days: int = DAYS) -> dict:
    """DAU, rolling WAU (7d) and MAU (28d), and stickiness DAU/MAU, per day."""
    by_day = defaultdict(set)
    for p, ds in activity.items():
        for d in ds:
            by_day[d].add(p)
    labels, dau, wau, mau, sticky = [], [], [], [], []
    for i in range(days - 1, -1, -1):
        d = today - dt.timedelta(days=i)
        w = set().union(*(by_day[d - dt.timedelta(days=k)] for k in range(7)))
        m = set().union(*(by_day[d - dt.timedelta(days=k)] for k in range(28)))
        avg_dau = sum(len(by_day[d - dt.timedelta(days=k)]) for k in range(28)) / 28
        labels.append(d.isoformat())
        dau.append(len(by_day[d]))
        wau.append(len(w))
        mau.append(len(m))
        sticky.append(round(100 * avg_dau / len(m), 1) if m else None)
    return {"labels": labels, "dau": dau, "wau": wau, "mau": mau, "stickiness": sticky}


def power_curve(activity: dict, today: dt.date, window: int) -> list[int]:
    """How many people were active on exactly 1..window days of the last `window` days."""
    start = today - dt.timedelta(days=window - 1)
    counts = Counter(sum(1 for d in ds if start <= d <= today) for ds in activity.values())
    return [counts.get(n, 0) for n in range(1, window + 1)]


def rolling_retention(activity: dict, first_seen: dict, today: dt.date) -> list[dict]:
    """Rolling Dn: of people who first appeared at least n days ago, the share seen again n+ days later."""
    out = []
    for n in (1, 7, 30):
        eligible = [p for p, f in first_seen.items() if f <= today - dt.timedelta(days=n)]
        kept = [p for p in eligible if max(activity[p]) >= first_seen[p] + dt.timedelta(days=n)]
        out.append({"day": n, "eligible": len(eligible), "kept": len(kept),
                    "pct": round(100 * len(kept) / len(eligible)) if eligible else None,
                    "benchmark": BENCHMARK_RETENTION[n]})
    return out


def cohorts(activity: dict, first_seen: dict, today: dt.date, weeks: int = 8) -> list[dict]:
    """Weekly cohorts by first appearance: share active again in each later week."""
    spans = periods(today, weeks)
    rows = []
    for i, (s, e) in enumerate(spans):
        members = [p for p, f in first_seen.items() if s <= f <= e]
        if not members:
            continue
        pct = []
        for ws, we in spans[i + 1:]:
            back = sum(1 for p in members if any(ws <= d <= we for d in activity[p]))
            pct.append(round(100 * back / len(members)))
        rows.append({"label": f"{s.day} {s:%b}", "size": len(members), "pct": pct})
    return rows


def change(now: float, prev: float) -> int | None:
    return round(100 * (now - prev) / prev) if prev else None


# --- Collect -----------------------------------------------------------------

FUNNEL = [
    ("Opened the app (new)", None),
    ("Started sign-up", "register_started"),
    ("Verified email", "otp_verified"),
    ("Created account", "signup_completed"),
    ("Tried the demo", "demo_started"),
    ("Finished the demo", "demo_reaction_completed"),
    # ponytail: "Added a friend" left out; friend_added only fires for the accepter
    # (undercounts), so it read as a false drop-off. Add back once that fix ships.
    ("Sent a first Reacti", "first_message_sent"),
    ("Got a first reaction back", "first_reaction_received"),
]


def collect_posthog(key: str, today: dt.date) -> dict:
    # Activity = opening the app. One row per person per active day.
    activity = defaultdict(set)
    for person, day in hogql(key, (
        f"SELECT person_id, toDate(timestamp) AS d FROM events WHERE event = 'app_open' AND {ENV} "
        f"AND timestamp > now() - INTERVAL 365 DAY GROUP BY person_id, d LIMIT {LIMIT}"
    )):
        activity[str(person)].add(dt.date.fromisoformat(str(day)[:10]))
    first_seen = {p: min(ds) for p, ds in activity.items()}

    # Daily event counts.
    counts = defaultdict(Counter)  # key -> {date: n}
    for day, event, mtype, result, n in hogql(key, (
        f"SELECT toDate(timestamp) AS d, event, coalesce(toString(properties.message_type), '') AS mt, "
        f"coalesce(toString(properties.result), '') AS r, count() FROM events WHERE {ENV} "
        f"AND timestamp > now() - INTERVAL {DAYS + 7} DAY AND event IN ('signup_completed', 'message_sent', "
        f"'reaction_sent', 'reaction_recorded', 'mark_viewed_result', 'invite_shared', 'invite_opened', "
        f"'invite_connected', 'friend_added', 'session_start', 'login_result') "
        f"GROUP BY d, event, mt, r LIMIT {LIMIT}"
    )):
        d = dt.date.fromisoformat(str(day)[:10])
        counts[event][d] += n
        counts[f"{event}:{result}"][d] += n
        if event == "message_sent" and result == "success":
            counts[f"message_sent:{mtype}"][d] += n

    def total(k: str, days: int, offset: int = 0) -> int:
        lo, hi = today - dt.timedelta(days=offset + days - 1), today - dt.timedelta(days=offset)
        return sum(n for d, n in counts[k].items() if lo <= d <= hi)

    def series(k: str) -> list[int]:
        return [counts[k].get(today - dt.timedelta(days=i), 0) for i in range(DAYS - 1, -1, -1)]

    people = dict(hogql(key, (
        f"SELECT event, count(DISTINCT person_id) FROM events WHERE {ENV} AND timestamp > now() - INTERVAL 90 DAY "
        f"AND event IN ({', '.join(repr(e) for _, e in FUNNEL if e)}) GROUP BY event"
    )))
    new_90 = sum(1 for f in first_seen.values() if f > today - dt.timedelta(days=90))
    funnel = [{"label": label, "value": new_90 if e is None else people.get(e, 0)} for label, e in FUNNEL]

    m = hogql(key, (
        "SELECT "
        "quantileIf(0.5)(toFloat(properties.ms_since_first_launch), event = 'signup_completed'), "
        "quantileIf(0.5)(toFloat(properties.elapsed_ms), event = 'mark_viewed_to_reaction'), "
        "quantileIf(0.5)(toFloat(properties.upload_ms), event = 'reaction_sent' AND properties.result = 'success'), "
        "quantileIf(0.5)(toFloat(properties.elapsed_ms), event = 'session_end'), "
        "quantileIf(0.5)(toFloat(properties.media_load_ms), event = 'media_loaded' AND properties.result = 'success'), "
        "quantileIf(0.9)(toFloat(properties.media_load_ms), event = 'media_loaded' AND properties.result = 'success'), "
        "quantileIf(0.5)(toFloat(properties.cold_start_ms), event = 'app_open' AND properties.is_cold_start = true), "
        "quantileIf(0.9)(toFloat(properties.latency_ms), event = 'api_request'), "
        "countIf(event = 'api_request'), "
        "countIf(event = 'api_request' AND (toInt(properties.status) >= 500 OR toInt(properties.status) = 0)), "
        "sumIf(toFloat(properties.jank_frame_count), event = 'frame_jank'), "
        "sumIf(toFloat(properties.frame_count), event = 'frame_jank'), "
        "quantileIf(0.5)(toFloat(properties.send_ms), event = 'message_sent' AND properties.result = 'success') "
        f"FROM events WHERE {ENV} AND timestamp > now() - INTERVAL 30 DAY AND event IN ('signup_completed', "
        "'mark_viewed_to_reaction', 'reaction_sent', 'session_end', 'media_loaded', 'app_open', 'api_request', "
        "'frame_jank', 'message_sent')"
    ))[0]
    (signup_ms, open_to_react_ms, react_upload_ms, session_ms, media_p50, media_p90, cold_start_ms,
     api_p90, api_total, api_errors, jank, frames, send_ms) = m

    def breakdown(event: str, prop: str, days: int = 30, where: str = "", distinct: bool = True, limit: int = 10) -> list:
        agg = "count(DISTINCT person_id)" if distinct else "count()"
        return [{"label": k, "value": n} for k, n in hogql(key, (
            f"SELECT coalesce(toString(properties.{prop}), 'unknown') AS k, {agg} AS n FROM events "
            f"WHERE event = '{event}' AND {ENV}{' AND ' + where if where else ''} "
            f"AND timestamp > now() - INTERVAL {days} DAY GROUP BY k ORDER BY n DESC LIMIT {limit}"
        ))]

    permissions = [{"label": p, "granted": g, "asked": a} for p, g, a in hogql(key, (
        f"SELECT properties.permission AS p, countIf(properties.result = 'granted'), count() FROM events "
        f"WHERE event = 'permission_result' AND {ENV} AND timestamp > now() - INTERVAL 90 DAY GROUP BY p ORDER BY count() DESC"
    ))]

    sec = lambda ms: round(ms / 1000, 1) if ms is not None else None  # noqa: E731
    da = daily_active(activity, today)
    wau, wau_prev = len(active_in(activity, today - dt.timedelta(days=6), today)), \
        len(active_in(activity, today - dt.timedelta(days=13), today - dt.timedelta(days=7)))
    mau, mau_prev = len(active_in(activity, today - dt.timedelta(days=27), today)), \
        len(active_in(activity, today - dt.timedelta(days=55), today - dt.timedelta(days=28)))
    new7 = sum(1 for f in first_seen.values() if f > today - dt.timedelta(days=7))
    new7_prev = sum(1 for f in first_seen.values() if today - dt.timedelta(days=14) < f <= today - dt.timedelta(days=7))

    return {
        "kpis": {
            "wau": [wau, wau_prev], "mau": [mau, mau_prev],
            "stickiness": [da["stickiness"][-1], da["stickiness"][-8]],
            "new_users": [new7, new7_prev],
            "signups": [total("signup_completed", 7), total("signup_completed", 7, 7)],
            "reactis": [total("message_sent:media", 7), total("message_sent:media", 7, 7)],
            "reactions": [total("reaction_sent:success", 7), total("reaction_sent:success", 7, 7)],
            "messages": [total("message_sent:success", 7), total("message_sent:success", 7, 7)],
        },
        "daily": {**da, "signups": series("signup_completed"), "reactis": series("message_sent:media"),
                  "reactions": series("reaction_sent:success"), "messages": series("message_sent:success")},
        "growth": growth_accounting(activity, first_seen, today),
        "power_l28": power_curve(activity, today, 28),
        "power_l7": power_curve(activity, today, 7),
        "retention": rolling_retention(activity, first_seen, today),
        "cohorts": cohorts(activity, first_seen, today),
        "funnel": funnel,
        "loop": {
            "sent": total("message_sent:media", 30), "opened": total("mark_viewed_result:success", 30),
            "recorded": total("reaction_recorded:success", 30), "returned": total("reaction_sent:success", 30),
            "record_failed": total("reaction_recorded:failure", 30),
            "open_to_react_s": sec(open_to_react_ms), "upload_s": sec(react_upload_ms), "send_s": sec(send_ms),
            "text": total("message_sent:text", 30), "media": total("message_sent:media", 30),
        },
        "engagement": {
            "session_s": sec(session_ms),
            "sessions": total("session_start", 30),
            "active_days_30": sum(len([d for d in ds if d > today - dt.timedelta(days=30)]) for ds in activity.values()),
        },
        "activation": {"signup_s": sec(signup_ms)},
        "network": {
            "invites_shared": total("invite_shared", 30), "invites_opened": total("invite_opened", 30),
            "invites_joined": total("invite_connected", 30), "friends_added": total("friend_added", 30),
        },
        "audience": {
            "countries": breakdown("app_open", "country"), "platforms": breakdown("app_open", "platform"),
            "versions": breakdown("app_open", "app_version"), "languages": breakdown("app_open", "language", limit=6),
        },
        "quality": {
            "login_ok": total("login_result:success", 30), "login_fail": total("login_result:failure", 30),
            "login_reasons": breakdown("login_result", "failure_reason", where="properties.result = 'failure'", distinct=False),
            "send_ok": total("message_sent:success", 30), "send_fail": total("message_sent:failure", 30),
            "send_reasons": breakdown("message_sent", "failure_reason", where="properties.result = 'failure'", distinct=False),
            "reaction_reasons": breakdown("reaction_recorded", "failure_reason", where="properties.result = 'failure'", distinct=False),
            "media_p50_s": sec(media_p50), "media_p90_s": sec(media_p90), "cold_start_s": sec(cold_start_ms),
            "api_p90_s": sec(api_p90), "api_error_pct": round(100 * api_errors / api_total, 1) if api_total else None,
            "smooth_pct": round(100 - 100 * jank / frames, 1) if frames else None,
            "permissions": permissions,
        },
    }


# --- App Store downloads (optional) -------------------------------------------

# Apple product types that are a first-time download (iPhone, universal, iPad).
FIRST_DOWNLOAD_TYPES = {"1", "1F", "1T", "F1"}


def parse_sales_tsv(text: str) -> tuple[int, Counter]:
    """First-time downloads in one Apple SUMMARY sales report, total and by country."""
    units, by_country = 0, Counter()
    for row in csv.DictReader(io.StringIO(text), delimiter="\t"):
        if row.get("Product Type Identifier", "").strip() in FIRST_DOWNLOAD_TYPES:
            n = int(float(row.get("Units") or 0))
            units += n
            by_country[row.get("Country Code", "??").strip()] += n
    return units, by_country


def collect_downloads(today: dt.date, days: int = 60) -> dict | None:
    env = {k: os.environ.get(k, "").strip() for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY", "ASC_VENDOR_NUMBER")}
    if not all(env.values()):
        return None
    try:
        import jwt  # PyJWT[crypto], installed by the workflow
    except ImportError:
        print("downloads skipped: PyJWT not installed", file=sys.stderr)
        return None
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    token = jwt.encode({"iss": env["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                       env["ASC_PRIVATE_KEY"].replace("\\n", "\n"), algorithm="ES256", headers={"kid": env["ASC_KEY_ID"]})
    labels, units, countries = [], [], Counter()
    for i in range(days, 0, -1):  # reports exist up to yesterday
        day = today - dt.timedelta(days=i)
        url = ("https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]=DAILY&filter[reportType]=SALES"
               f"&filter[reportSubType]=SUMMARY&filter[version]=1_0&filter[vendorNumber]={env['ASC_VENDOR_NUMBER']}"
               f"&filter[reportDate]={day.isoformat()}")
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/a-gzip"})
        n = 0
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                n, c = parse_sales_tsv(gzip.decompress(r.read()).decode("utf-8"))
                countries.update(c)
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                print(f"downloads skipped: App Store Connect refused the key ({e.code})", file=sys.stderr)
                return None
            # 404 = no sales that day (or report not ready yet): counts as 0.
        labels.append(day.isoformat())
        units.append(n)
    return {"labels": labels, "units": units, "countries": [{"label": k, "value": v} for k, v in countries.most_common(10)]}


# --- Plain-language insights ---------------------------------------------------

def pct(a: float, b: float) -> int:
    return round(100 * a / b) if b else 0


def insights(d: dict) -> list[dict]:
    """Ranked findings: level (critical/warning/good/info), title, detail, action."""
    out = []

    def add(level, title, detail, action, n=None):
        # n = how many people/events the finding rests on; under 30 it is an early signal.
        out.append({"level": level, "title": title, "detail": detail, "action": action,
                    "early": n is not None and n < 30})

    k = d["kpis"]

    # Growth health.
    g = [w for w in d["growth"] if w["quick_ratio"] is not None][-4:]
    if g:
        gained = sum(w["new"] + w["resurrected"] for w in g)
        lost = sum(w["churned"] for w in g)
        qr = round(gained / lost, 2) if lost else None
        if qr is not None and qr < 1:
            add("critical", f"The active base is shrinking (quick ratio {qr})",
                f"In the last 4 weeks Reacti gained {gained} active people (new + returning) and lost {lost}. "
                "Healthy consumer apps sit above 1, great ones above 4.",
                "Growth needs both: more new people (invites, store page) and fewer leaving after week one (see retention).",
                gained + lost)
        elif qr is not None:
            add("good", f"More people arriving than leaving (quick ratio {qr})",
                f"{gained} gained vs {lost} lost over the last 4 weeks.", "Keep the acquisition push going.", gained + lost)

    # Retention vs benchmark.
    for r in d["retention"]:
        if r["pct"] is None or r["eligible"] < 5:
            continue
        if r["pct"] < r["benchmark"] * 0.7:
            add("warning", f"Day-{r['day']} retention is {r['pct']}%, below a typical social app (~{r['benchmark']}%)",
                f"Of {r['eligible']} people who could have come back after {r['day']} day(s), {r['kept']} did.",
                "Give people a reason to return: a reaction waiting for them, a friend joining, a timely notification.",
                r["eligible"])
        elif r["day"] == 30 and r["pct"] >= r["benchmark"]:
            add("good", f"Day-30 retention of {r['pct']}% beats a typical social app (~{r['benchmark']}%)",
                "People who stay past the first weeks keep using Reacti.", "Double down on getting new people through week one.",
                r["eligible"])

    # Stickiness.
    s = k["stickiness"][0]
    if s is not None:
        if s < 20:
            add("warning", f"Stickiness (DAU/MAU) is {s}%",
                "On an average day only this share of the month's users opens Reacti. Messaging leaders run 50%+; 25% is OK.",
                "Daily habits come from daily triggers: streaks, daily prompts, or reactions arriving from friends.",
                k["mau"][0])
        elif s >= 40:
            add("good", f"Strong stickiness: {s}% DAU/MAU", "People use Reacti most days.", "Protect this habit.", k["mau"][0])

    # Activation: biggest drop after sign-up.
    f = {x["label"]: x["value"] for x in d["funnel"]}
    if f.get("Created account"):
        steps = ["Created account", "Sent a first Reacti", "Got a first reaction back"]
        drops = [(a, b, f[a], f[b]) for a, b in zip(steps, steps[1:]) if f.get(a)]
        if drops:
            a, b, na, nb = min(drops, key=lambda x: x[3] / x[2])
            if nb < na * 0.7:  # ponytail: a 5→4 wobble is noise, not a finding
                add("critical" if nb / na < 0.4 else "warning", f"New people get stuck between “{a}” and “{b}”",
                    f"{na} reached “{a}”, only {nb} reached “{b}” in the last 90 days (counted per step).",
                    "Reacti only works with friends. Make adding or inviting a friend part of sign-up, and pre-fill a first Reacti.",
                    na)

    # Loop health.
    lp = d["loop"]
    if lp["opened"] >= 5:
        rate = pct(lp["returned"], lp["opened"])
        add("good" if rate >= 70 else "warning", f"{rate}% of opened Reactis sent a reaction back",
            f"{lp['opened']} Reactis were opened and {lp['returned']} reactions came back in 30 days.",
            "This is the core promise: keep it above 80%." if rate >= 70
            else "Check why reactions do not come back: camera permission, failures, slow uploads.", lp["opened"])
    if lp["text"] + lp["media"] >= 20 and lp["media"] < lp["text"] * 0.4:
        add("info", f"Most messages are text ({pct(lp['text'], lp['text'] + lp['media'])}%)",
            "Only photo/video messages capture reactions, so text-heavy chats skip Reacti's magic.",
            "Nudge toward media: a camera shortcut in chat, or suggesting a Reacti when a chat is text-only.",
            lp["text"] + lp["media"])

    # Invites.
    nw = d["network"]
    if nw["invites_opened"] >= 5 and nw["invites_joined"] == 0:
        add("warning", "Invite links are opened but nobody is recorded as joining through them",
            f"{nw['invites_opened']} opens, 0 joins in 30 days.",
            "Walk the invite path on a fresh phone: link, store, sign-up, friend added automatically.", nw["invites_opened"])

    # Quality.
    q = d["quality"]
    attempts = q["login_ok"] + q["login_fail"]
    if attempts >= 5 and q["login_fail"] / attempts >= 0.2:
        reason = q["login_reasons"][0]["label"].replace("_", " ") if q["login_reasons"] else "unknown"
        add("critical", f"{pct(q['login_fail'], attempts)}% of sign-in attempts fail",
            f"{q['login_fail']} of {attempts} attempts in 30 days. Most common reason: {reason}.",
            "Make the error say what to do, show “Forgot password” prominently, and consider email-code sign-in.", attempts)
    if q["media_p90_s"] and q["media_p90_s"] > 3:
        add("warning", f"Slow photos/videos for some people (slowest 10%: {q['media_p90_s']}s)",
            "A Reacti that loads slowly delays the moment the reaction is captured.", "Smaller previews and earlier prefetch.")
    if q["api_error_pct"] and q["api_error_pct"] >= 2:
        add("warning", f"{q['api_error_pct']}% of server requests fail", "Includes server errors and dropped connections.",
            "Check the server error log for the most common failing endpoint.")
    for p in q["permissions"]:
        if p["label"] == "notifications" and p["asked"] >= 5 and p["granted"] / p["asked"] < 0.7:
            add("warning", f"Only {pct(p['granted'], p['asked'])}% allow notifications",
                "Without them people never hear that a reaction came back.",
                "Ask at the moment it matters: right after sending a first Reacti.", p["asked"])

    order = {"critical": 0, "warning": 1, "info": 2, "good": 3}
    return sorted(out, key=lambda x: order[x["level"]])


def summary(d: dict) -> str:
    """One executive sentence for the top of the page."""
    k = d["kpis"]

    def trend(pair):
        c = change(*pair)
        return "" if c is None else f" ({'up' if c >= 0 else 'down'} {abs(c)}% on the week before)"

    parts = [f"In the last 7 days {k['wau'][0]} people used Reacti{trend(k['wau'])}",
             f"{k['reactis'][0]} Reactis were sent and {k['reactions'][0]} reactions came back"]
    if k["new_users"][0]:
        parts.append(f"{k['new_users'][0]} people opened it for the first time")
    return ", ".join(parts) + "."


# --- Render ------------------------------------------------------------------

def collect(key: str) -> dict:
    today = dt.datetime.now(dt.timezone.utc).date()
    data = collect_posthog(key, today)
    data["downloads"] = collect_downloads(today)
    data["generated_at"] = dt.datetime.now(dt.timezone.utc).strftime("%d %b %Y, %H:%M UTC")
    data["insights"] = insights(data)
    data["summary"] = summary(data)
    return data


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
