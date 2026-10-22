"""Build the "Reacti Insights" website: one self-contained HTML page with the
production analytics, rebuilt hourly by .github/workflows/insights-site.yml
and published to Cloudflare Pages.

Read-only. Pulls aggregates from PostHog (and, when configured, App Store
Connect sales reports) and renders them into insights_template.html. The page
never shows an individual, a message or any media.

Statistics only: no findings, benchmarks or recommendations (Achia's call,
2026-10-19). The top of the page is "Product validation" (the partner's five
questions, from the database); below it everything else: growth accounting
and quick ratio, DAU/MAU, power-user curve, cohort retention, activation, and
the Reacti loop.

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
    INSIGHTS_API_TOKEN    (optional) shared secret for the backend's
                          /api/internal/insights; without it the product
                          section shows as waiting.
    INSIGHTS_API_URL      default https://reacti.io/api/internal/insights
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
# Hand-written: milestones ("what changed and why", drawn on the charts) and goals.
NOTES = Path(__file__).with_name("insights_notes.json")
# ponytail: Android events before 2026-10-20 are Google Play's pre-launch robots (9 Oct), not people;
# from the next Android build the app switches analytics off inside Google's test lab.
ENV = "properties.analytics_env = 'production' AND NOT (properties.platform = 'android' AND timestamp < '2026-10-20')"
# ponytail: HogQL caps a result at 50k rows; the activity query returns one row
# per person per active day, so past ~400 daily users move it to a daily rollup.
LIMIT = 50000
DAYS = 90      # length of the daily charts
WEEKS = 12     # length of the weekly charts

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
                    "pct": round(100 * len(kept) / len(eligible)) if eligible else None})
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


def month_starts(today: dt.date, n: int) -> list[dt.date]:
    """First day of the last n calendar months, oldest first (this month included)."""
    y, m = today.year, today.month
    out = []
    for _ in range(n):
        out.append(dt.date(y, m, 1))
        y, m = (y, m - 1) if m > 1 else (y - 1, 12)
    return out[::-1]


def monthly(activity: dict, counts: dict, today: dt.date, months: int = 6) -> list[dict]:
    """Calendar-month totals; the current month is month-to-date."""
    starts = month_starts(today, months)
    rows = []
    for s, nxt in zip(starts, starts[1:] + [today + dt.timedelta(days=1)]):
        e = nxt - dt.timedelta(days=1)
        tot = lambda k: sum(n for d, n in counts.get(k, {}).items() if s <= d <= e)  # noqa: E731
        rows.append({"month": s.strftime("%Y-%m"), "partial": e >= today, "active": len(active_in(activity, s, e)),
                     "signups": tot("signup_completed"), "reactis": tot("message_sent:media"),
                     "reactions": tot("reaction_sent:success"), "messages": tot("message_sent:success")})
    # Months before an event existed show as "no data" (None), not as a real zero.
    keys = ("active", "signups", "reactis", "reactions", "messages")
    for k in keys:
        for r in rows:
            if r[k]:
                break
            r[k] = None
    while rows and all(rows[0][k] is None for k in keys):
        rows.pop(0)
    return rows


def funnel_new_only(steps: list, event_people: dict, new_people: set) -> list[dict]:
    """Funnel over NEW people; the steps after sign-up count only those who created an account.

    Sign-up steps count anyone who reached that step or a later one: each fires once per install,
    so a retried sign-up records "Created account" without its "Started sign-up". The later steps
    are limited to new accounts because people signed up before analytics existed also take the
    demo, and would otherwise read as more accounts than were created.
    """
    def got(events):
        return set().union(*(event_people.get(e, set()) for e in events)) & new_people

    accounts = got(SIGNUP)
    return [{"label": label, "value": len(new_people if e is None
                                          else got(SIGNUP[SIGNUP.index(e):]) if e in SIGNUP
                                          else got([e]) & accounts)}
            for label, e in steps]


def merge_ratings(per_country: dict) -> dict:
    """{country: (avg, count)} -> overall weighted average and total count."""
    n = sum(c for _, c in per_country.values())
    avg = round(sum(a * c for a, c in per_country.values()) / n, 1) if n else None
    return {"average": avg, "count": n,
            "countries": sorted(({"label": k, "value": c} for k, (_, c) in per_country.items() if c), key=lambda x: -x["value"])}


# --- Collect -----------------------------------------------------------------

SIGNUP = ["register_started", "otp_verified", "signup_completed"]  # in order
FUNNEL = [
    ("Opened the app (new)", None),
    ("Started sign-up", "register_started"),
    ("Verified email", "otp_verified"),
    ("Created account", "signup_completed"),
    ("Tried the demo", "demo_started"),
    ("Finished the demo", "demo_reaction_completed"),
    # friend_added fires for both people from app 1.7.0 (live 2026-10-20); on 1.6.0 only the accepter.
    ("Added a friend", "friend_added"),
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
        f"AND timestamp > now() - INTERVAL 200 DAY AND event IN ('signup_completed', 'message_sent', "
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

    event_people = defaultdict(set)
    for event, person in hogql(key, (
        f"SELECT event, person_id FROM events WHERE {ENV} AND timestamp > now() - INTERVAL 90 DAY "
        f"AND event IN ({', '.join(repr(e) for _, e in FUNNEL if e)}, 'invite_shared') GROUP BY event, person_id LIMIT {LIMIT}"
    )):
        event_people[event].add(str(person))
    new_90 = {p for p, f in first_seen.items() if f > today - dt.timedelta(days=90)}
    funnel = funnel_new_only(FUNNEL, event_people, new_90)

    # When each app version first reached production users: release markers on the charts.
    versions = [{"date": str(d)[:10], "text": f"App {v} reaches users", "tag": v} for v, d in hogql(key, (
        f"SELECT toString(properties.app_version) AS v, min(toDate(timestamp)) FROM events WHERE event = 'app_open' "
        f"AND {ENV} AND properties.app_version IS NOT NULL AND v != '' GROUP BY v HAVING count(DISTINCT person_id) >= 2 ORDER BY 2"
    ))]

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
            "invites_shared": total("invite_shared", 90), "invites_opened": total("invite_opened", 90),
            "invites_joined": total("invite_connected", 90), "friends_added": total("friend_added", 90),
            "inviters": len(event_people["invite_shared"]),
        },
        "monthly": monthly(activity, counts, today),
        "versions": versions,
        "audience": {
            "countries": breakdown("app_open", "country"), "countries_ever": breakdown("app_open", "country", days=3650, limit=20), "platforms": breakdown("app_open", "platform"),
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
    class Refused(Exception):
        pass

    def report(frequency: str, date: str) -> tuple[int, Counter]:
        url = (f"https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]={frequency}&filter[reportType]=SALES"
               f"&filter[reportSubType]=SUMMARY&filter[version]=1_0&filter[vendorNumber]={env['ASC_VENDOR_NUMBER']}"
               f"&filter[reportDate]={date}")
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/a-gzip"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return parse_sales_tsv(gzip.decompress(r.read()).decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                detail = e.read().decode("utf-8", "replace")[:400]  # Apple's error JSON, no secrets
                raise Refused(f"App Store Connect refused the key ({e.code}): {detail}")
            return 0, Counter()  # 404 = no sales that period (or report not ready yet)

    labels, units, countries = [], [], Counter()
    try:
        for i in range(days, 0, -1):  # reports exist up to yesterday
            day = today - dt.timedelta(days=i)
            n, c = report("DAILY", day.isoformat())
            countries.update(c)
            labels.append(day.isoformat())
            units.append(n)
        # Full past months come from Apple's monthly report; the current month is summed from the daily ones.
        months = {s.strftime("%Y-%m"): report("MONTHLY", s.strftime("%Y-%m"))[0] for s in month_starts(today, 6)[:-1]}
    except Refused as e:
        print(f"downloads skipped: {e}", file=sys.stderr)
        return None
    months[today.strftime("%Y-%m")] = sum(n for d, n in zip(labels, units) if d.startswith(today.strftime("%Y-%m")))
    return {"labels": labels, "units": units, "months": months,
            "countries": [{"label": k, "value": v} for k, v in countries.most_common(10)]}


# --- Sentry crash-free users (optional) ------------------------------------------

SENTRY_API = "https://de.sentry.io/api/0/organizations/reacti/sessions/"
SENTRY_APP_PROJECT = "4511565805256784"  # the "flutter" project


def collect_crash_free() -> dict | None:
    """Share of app users with no crash (Sentry release health), production only. Needs SENTRY_READ_TOKEN."""
    token = os.environ.get("SENTRY_READ_TOKEN", "").strip()
    if not token:
        return None
    out = {}
    for period in ("7d", "30d"):
        url = (f"{SENTRY_API}?project={SENTRY_APP_PROJECT}&environment=production&statsPeriod={period}&interval=1d"
               "&field=crash_free_rate(user)&field=count_unique(user)")
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"}), timeout=30) as r:
                g = (json.loads(r.read()).get("groups") or [{}])[0]
        except (urllib.error.URLError, ValueError) as e:
            print(f"crash-free skipped: {e}", file=sys.stderr)
            return None
        rate, users = g.get("totals", {}).get("crash_free_rate(user)"), g.get("totals", {}).get("count_unique(user)")
        out[period] = {"pct": round(100 * rate, 1) if rate is not None else None, "users": users or 0}
    return out


# --- App Store ratings (public, no key) ----------------------------------------

APP_STORE_ID = "6755814897"


def fetch_json(url: str):
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return json.loads(r.read())
    except (urllib.error.URLError, ValueError) as e:
        print(f"ratings: {url} failed: {e}", file=sys.stderr)
        return None


def collect_ratings(countries: list[str]) -> dict:
    """Star rating per storefront (Apple keeps them per country) and the latest written reviews."""
    per_country, reviews = {}, []
    for cc in countries:
        res = (fetch_json(f"https://itunes.apple.com/lookup?id={APP_STORE_ID}&country={cc}") or {}).get("results") or [{}]
        per_country[cc.upper()] = (res[0].get("averageUserRating") or 0, res[0].get("userRatingCount") or 0)
        entries = ((fetch_json(f"https://itunes.apple.com/{cc}/rss/customerreviews/id={APP_STORE_ID}/sortby=mostrecent/json")
                    or {}).get("feed") or {}).get("entry") or []
        for e in entries if isinstance(entries, list) else [entries]:
            if "im:rating" in e:  # author names are left out on purpose
                reviews.append({"country": cc.upper(), "stars": int(e["im:rating"]["label"]), "title": e["title"]["label"],
                                "text": e["content"]["label"][:280], "date": e["updated"]["label"][:10]})
    return {**merge_ratings(per_country), "reviews": sorted(reviews, key=lambda r: r["date"], reverse=True)[:6]}


# --- Product validation (database journeys) ------------------------------------

INSIGHTS_API = os.environ.get("INSIGHTS_API_URL", "https://reacti.io/api/internal/insights")


def fetch_journeys() -> list | None:
    """Anonymous per-person journeys from the backend, or None when not configured or unreachable."""
    token = os.environ.get("INSIGHTS_API_TOKEN", "").strip()
    if not token:
        return None
    # Cloudflare sits in front of reacti.io and refuses urllib's default user agent.
    req = urllib.request.Request(INSIGHTS_API, headers={"Authorization": f"Bearer {token}", "Accept": "application/json",
                                                        "User-Agent": "reacti-insights/1"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read())["data"]["users"]
    except (urllib.error.URLError, ValueError, KeyError) as e:
        print(f"insights api: {e}", file=sys.stderr)
        return None


def journey_steps(user: dict) -> tuple[bool, bool, bool]:
    """(sent a Reacti, one got a reaction back, sent another on a later day than that first reaction)."""
    sent = [(dt.date.fromisoformat(r[0]), r[2]) for r in user["sent"]]
    first_ok = min((d for d, reacted in sent if reacted), default=None)
    return bool(sent), first_ok is not None, first_ok is not None and any(d > first_ok for d, _ in sent)


def product(users: list, today: dt.date) -> dict:
    """The partner's five questions, counted from the journeys. Pairs are [last 7 days, the 7 before]."""
    day = dt.date.fromisoformat

    def joined(u):
        return day(u["joined"])

    weeks = [(today - dt.timedelta(days=6), today), (today - dt.timedelta(days=13), today - dt.timedelta(days=7))]

    def reactis(lo, hi):
        rs = [r for u in users for r in u["sent"] if lo <= day(r[0]) <= hi]
        return {"sent": len(rs), "opened": sum(r[1] for r in rs), "reacted": sum(r[2] for r in rs), "watched": sum(r[3] for r in rs)}

    def strip(cohort):
        steps = [journey_steps(u) for u in cohort]
        return [len(steps)] + [sum(s[i] for s in steps) for i in range(3)]

    def senders(lo, hi):
        return [u for u in users if any(lo <= day(r[0]) <= hi for r in u["sent"])]

    # Activation: accounts old enough to have had their 7 days, from the last 90.
    eligible = [u for u in users if today - dt.timedelta(days=97) < joined(u) <= today - dt.timedelta(days=7)]
    received = [u for u in users if u["first_received"]]
    # A recipient "became a sender" only if their first Reacti came on or after the first one they got.
    became = [u for u in received if u["sent"] and day(u["sent"][0][0]) >= day(u["first_received"])]
    ever_sent = [u for u in users if u["sent"]]
    return {
        "total_users": len(users),
        "new_accounts": [sum(lo <= joined(u) <= hi for u in users) for lo, hi in weeks],
        "strip": {"d90": strip([u for u in users if joined(u) > today - dt.timedelta(days=90)]), "all": strip(users)},
        "activation": {"eligible": len(eligible),
                       "sent_7d": sum(any(day(r[0]) <= joined(u) + dt.timedelta(days=7) for r in u["sent"]) for u in eligible)},
        "reactis": [reactis(lo, hi) for lo, hi in weeks],
        "reactis_30": reactis(today - dt.timedelta(days=29), today),
        "senders": [len(senders(lo, hi)) for lo, hi in weeks],
        # Senders in the week who had also sent before it.
        "repeat_senders": [sum(any(day(r[0]) < lo for r in u["sent"]) for u in senders(lo, hi)) for lo, hi in weeks],
        "multi_day": [sum(len({r[0] for r in u["sent"]}) > 1 for u in ever_sent), len(ever_sent)],
        "organic": {"recipients": len([u for u in received if not u["sent"] or day(u["sent"][0][0]) >= day(u["first_received"])]),
                    "became_senders": len(became)},
    }


# --- Summary ---------------------------------------------------------------------

def summary(d: dict) -> str:
    """One factual sentence for the top of the page."""
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
    dl = data["downloads"] = collect_downloads(today)
    if dl:
        data["kpis"]["downloads"] = [sum(dl["units"][-7:]), sum(dl["units"][-14:-7])]
        for row in data["monthly"]:
            row["downloads"] = dl["months"].get(row["month"])
    stores = {"us", "il"} | {c["label"].lower() for c in (dl or {}).get("countries", [])} \
        | {c["label"].lower() for c in data["audience"]["countries"] if len(c["label"]) == 2}
    data["ratings"] = collect_ratings(sorted(stores))
    journeys = fetch_journeys()
    data["product"] = product(journeys, today) if journeys is not None else None
    data["quality"]["crash_free"] = collect_crash_free()
    notes = json.loads(NOTES.read_text(encoding="utf-8")) if NOTES.exists() else {}
    data["milestones"] = sorted(notes.get("milestones", []) + data.pop("versions"), key=lambda m: m["date"])
    data["goals"] = notes.get("goals", [])
    data["generated_at"] = dt.datetime.now(dt.timezone.utc).strftime("%d %b %Y, %H:%M UTC")
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
    # The weekly email reads this; it holds nothing the page itself doesn't.
    out.with_name("data.json").write_text(json.dumps(data), encoding="utf-8")
    if args.json:
        Path(args.json).write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"wrote {out} ({len(html) // 1024} KB), data as of {data['generated_at']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
