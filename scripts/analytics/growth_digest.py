#!/usr/bin/env python3
"""Pull the growth digest from PostHog (read-only): who arrives, whether they
activate, how long it takes, and whether they come back.

This is the reading half of the analytics work - the counterpart to
``perf_digest.py``, which reports speed. Four sections, each answering one of
the questions the instrumentation was built for:

1. **Activation funnel** - how many distinct people reach each step from
   opening the app to receiving their first Reacti, with the drop at each
   step and the median time from first launch (time-to-value).
2. **Walkthrough effect** - do people who see the walkthrough activate at a
   higher rate than people who do not? The only way to know whether the
   onboarding work pays.
3. **Where they are from** - coarse country, from the device locale.
4. **Rolling retention** - D1/D7/D30, counting only people who have existed
   long enough to qualify (see ``build_retention_query``).

Read-only by design: it only issues HogQL ``/query`` reads, and reports counts
and medians - never an individual. **No secret lives in the repo** - the key
comes from the ``POSTHOG_READONLY_KEY`` environment variable.

Usage:
    POSTHOG_READONLY_KEY=phx_... python scripts/analytics/growth_digest.py \
        --env production --days 30

Environment variables:
    POSTHOG_READONLY_KEY   (required) read-only personal API key.
    POSTHOG_HOST           PostHog host (default https://eu.posthog.com).
    POSTHOG_PROJECT_ID     project id (default 202061).

Exit codes: 0 ok; 2 missing key; 1 API/query error.
"""
import argparse
import os
import sys
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from perf_digest import DEFAULT_HOST, DEFAULT_PROJECT, run_query  # noqa: E402

# Cohort window for retention. Independent of --days: a D30 number needs people
# who first appeared at least 30 days ago, so the retention cohort always looks
# back further than the funnel window does.
RETENTION_COHORT_DAYS = 120

# The activation chain, in order. Each step is (label, event name). Conversion
# is reported against the step above, so the order is load-bearing.
FUNNEL = [
    ("App opened", "app_open"),
    ("Signup started", "register_started"),
    ("Email verified", "otp_verified"),
    ("Account created", "signup_completed"),
    ("First friend", "friend_added"),
    ("First Reacti sent", "first_message_sent"),
    ("First reaction back", "first_reaction_received"),
]

# Retention days to report.
RETENTION_DAYS = [1, 7, 30]

# The OS dialogs worth reading, in the order they matter. Camera first: a
# refusal there means the person cannot use the app at all.
PERMISSIONS = ["camera", "microphone", "notifications", "contacts"]


def build_funnel_query(env: str, days: int) -> str:
    """Builds one HogQL row: distinct people per funnel step + median timing.

    Counts people rather than events - one person opening the app forty times
    is one person, and a funnel that counts events flatters itself.

    :param env: ``analytics_env`` value, already validated to an enum.
    :param days: look-back window in days.
    :return: a HogQL query string.
    """
    cols = []
    for i, (_, event) in enumerate(FUNNEL):
        cols.append(f"uniqIf(person_id, event = '{event}') as n{i}")
        # ms_since_first_launch rides every activation event; the median is the
        # honest summary because a handful of people leave the app installed for
        # weeks before signing up and would drag a mean anywhere.
        cols.append(
            f"quantile(0.5)(if(event = '{event}', "
            f"toFloat(properties.ms_since_first_launch), null)) as t{i}"
        )
    select = ",\n  ".join(cols)
    return (
        f"select\n  {select}\n"
        f"from events\n"
        f"where properties.analytics_env = '{env}'\n"
        f"  and timestamp >= now() - toIntervalDay({days})"
    )


def build_walkthrough_query(env: str, days: int) -> str:
    """Builds the walkthrough-versus-no-walkthrough activation comparison.

    Groups events by person first, then counts people in each bucket, so the
    result reads "x of y people who saw it went on to send", not a ratio of
    raw event counts.

    Correlation, not proof: people who sit through a walkthrough are keener to
    begin with. A large gap is still the strongest signal available short of
    running a split test.

    :param env: ``analytics_env`` value, already validated to an enum.
    :param days: look-back window in days.
    :return: a HogQL query string.
    """
    return (
        "select\n"
        "  countIf(saw > 0) as saw,\n"
        "  countIf(saw > 0 and activated > 0) as saw_activated,\n"
        "  countIf(saw = 0) as unseen,\n"
        "  countIf(saw = 0 and activated > 0) as unseen_activated\n"
        "from (\n"
        "  select person_id,\n"
        "    countIf(event = 'walkthrough_step_shown') as saw,\n"
        "    countIf(event = 'first_message_sent') as activated\n"
        "  from events\n"
        f"  where properties.analytics_env = '{env}'\n"
        f"    and timestamp >= now() - toIntervalDay({days})\n"
        "  group by person_id\n"
        ")"
    )


def build_country_query(env: str, days: int) -> str:
    """Builds the top-10 country breakdown, by distinct people.

    ``country`` is the coarse device-locale region (``IL``, ``US``) - a
    non-identifying property, and the only geography collected.

    :param env: ``analytics_env`` value, already validated to an enum.
    :param days: look-back window in days.
    :return: a HogQL query string.
    """
    return (
        "select properties.country as country, uniq(person_id) as people\n"
        "from events\n"
        f"where properties.analytics_env = '{env}'\n"
        f"  and timestamp >= now() - toIntervalDay({days})\n"
        "  and properties.country != ''\n"
        "group by country\n"
        "order by people desc\n"
        "limit 10"
    )


def build_retention_query(env: str) -> str:
    """Builds rolling D1/D7/D30 retention.

    Two decisions worth knowing when reading the output:

    * **Rolling, not day-boxed.** "Retained at D7" means seen *on or after*
      seven days from first appearance, not specifically on day seven. Rolling
      retention is the steadier of the two conventions at Reacti's volumes,
      where a day-boxed number swings on a handful of people.
    * **Only the eligible are counted.** Someone who arrived yesterday cannot
      have a D7 outcome yet, so they are left out of the D7 denominator rather
      than counted as lost. Skipping this is the usual reason a retention chart
      looks like it is collapsing when it is not.

    :param env: ``analytics_env`` value, already validated to an enum.
    :return: a HogQL query string.
    """
    cols = []
    for d in RETENTION_DAYS:
        eligible = f"first_seen <= now() - toIntervalDay({d})"
        cols.append(f"countIf({eligible}) as elig{d}")
        cols.append(
            f"countIf({eligible} and last_seen >= first_seen + toIntervalDay({d}))"
            f" as ret{d}"
        )
    select = ",\n  ".join(cols)
    return (
        f"select\n  {select}\n"
        "from (\n"
        "  select person_id,\n"
        "    min(timestamp) as first_seen,\n"
        "    max(timestamp) as last_seen\n"
        "  from events\n"
        f"  where properties.analytics_env = '{env}'\n"
        f"    and timestamp >= now() - toIntervalDay({RETENTION_COHORT_DAYS})\n"
        "  group by person_id\n"
        ")"
    )


def build_permission_query(env: str, days: int) -> str:
    """Builds the current answer to each OS permission dialog, per person.

    Takes each person's **latest** answer rather than counting every event.
    The app reports every answer, so someone who denies the camera and later
    allows it emits both; counting raw events would place one person in two
    buckets and understate the denial rate, which is the direction that
    flatters and the one number this section exists to report honestly.

    :param env: ``analytics_env`` value, already validated to an enum.
    :param days: look-back window in days.
    :return: a HogQL query string.
    """
    return (
        "select permission,\n"
        "  countIf(latest = 'granted') as granted,\n"
        "  countIf(latest in ('denied', 'permanently_denied')) as denied,\n"
        "  count() as answered\n"
        "from (\n"
        "  select person_id,\n"
        "    properties.permission as permission,\n"
        "    argMax(properties.result, timestamp) as latest\n"
        "  from events\n"
        "  where event = 'permission_result'\n"
        f"    and properties.analytics_env = '{env}'\n"
        f"    and timestamp >= now() - toIntervalDay({days})\n"
        "  group by person_id, permission\n"
        ")\n"
        "group by permission"
    )


def build_usage_query(env: str, days: int) -> str:
    """Builds sign-in outcomes, session length, and the ways people leave.

    One query rather than four: every line counts distinct people over the
    same window, so splitting them would be four round trips for one row.

    :param env: ``analytics_env`` value, already validated to an enum.
    :param days: look-back window in days.
    :return: a HogQL query string.
    """
    return (
        "select\n"
        "  uniqIf(person_id, event = 'login_result'"
        " and properties.result = 'success') as signed_in,\n"
        "  uniqIf(person_id, event = 'login_result'"
        " and properties.result = 'failure') as sign_in_failed,\n"
        "  uniqIf(person_id, event = 'friend_removed') as unfriended,\n"
        "  uniqIf(person_id, event = 'group_left') as left_group,\n"
        "  uniqIf(person_id, event = 'account_deleted') as deleted,\n"
        "  quantile(0.5)(if(event = 'session_end',"
        " toFloat(properties.elapsed_ms), null)) as session_ms\n"
        "from events\n"
        f"where properties.analytics_env = '{env}'\n"
        f"  and timestamp >= now() - toIntervalDay({days})"
    )


def pct(part, whole) -> str:
    """Formats ``part``/``whole`` as a percentage, or 'n/a' with no denominator.

    :param part: numerator; ``None`` counts as zero.
    :param whole: denominator; zero or ``None`` yields ``'n/a'``.
    :return: e.g. ``'42%'``.
    """
    if not whole:
        return "n/a"
    return f"{round(100 * (part or 0) / whole)}%"


def human_ms(value) -> str:
    """Formats a duration in milliseconds as the largest sensible unit.

    Time-to-value spans seconds to weeks, so a single fixed unit reads badly at
    one end or the other.

    :param value: milliseconds, or ``None`` when there were no samples.
    :return: e.g. ``'45s'``, ``'12m'``, ``'3.1d'``, or ``'-'``.
    """
    if value is None:
        return "-"
    seconds = float(value) / 1000
    if seconds < 90:
        return f"{seconds:.0f}s"
    if seconds < 5400:
        return f"{seconds / 60:.0f}m"
    if seconds < 172800:
        return f"{seconds / 3600:.0f}h"
    return f"{seconds / 86400:.1f}d"


def print_funnel(row) -> None:
    """Prints the activation funnel with step conversion and time-to-value.

    :param row: the single result row from :func:`build_funnel_query`.
    """
    print("ACTIVATION FUNNEL           people    of prev   median from launch")
    previous = None
    for i, (label, _) in enumerate(FUNNEL):
        people, elapsed = row[i * 2], row[i * 2 + 1]
        step = "-" if previous is None else pct(people, previous)
        print(f"  {label:<24} {people:>7}   {step:>7}   {human_ms(elapsed):>10}")
        previous = people
    if row[0]:
        print(f"  {'end to end':<24} {'':>7}   {pct(previous, row[0]):>7}")


def print_walkthrough(row) -> None:
    """Prints activation rates with and without the walkthrough.

    :param row: the single result row from :func:`build_walkthrough_query`.
    """
    saw, saw_act, unseen, unseen_act = row
    print("\nWALKTHROUGH               people   activated    rate")
    print(f"  {'saw it':<22} {saw:>7}   {saw_act:>9}   {pct(saw_act, saw):>5}")
    print(f"  {'did not':<22} {unseen:>7}   {unseen_act:>9}   "
          f"{pct(unseen_act, unseen):>5}")


def print_countries(rows) -> None:
    """Prints the country breakdown, or a note when no country was recorded.

    :param rows: result rows of ``(country, people)`` from the country query.
    """
    print("\nWHERE THEY ARE")
    if not rows:
        print("  (no country recorded yet)")
        return
    for country, people in rows:
        print(f"  {country:<22} {people:>7}")


def print_retention(row) -> None:
    """Prints rolling retention against its eligible denominator.

    :param row: the single result row from :func:`build_retention_query`.
    """
    print("\nROLLING RETENTION          kept   of eligible")
    for i, d in enumerate(RETENTION_DAYS):
        eligible, retained = row[i * 2], row[i * 2 + 1]
        label = f"D{d}"
        print(f"  {label:<22} {retained:>7}   {pct(retained, eligible):>7}"
              f"  (n={eligible})")


def print_permissions(rows) -> None:
    """Prints what the OS permission dialogs came back with.

    The camera line is the one to read first: a denial there is not a soft
    preference, it is a person who cannot use the app at all and who looks
    identical to a disinterested user everywhere else in this digest.

    :param rows: ``(permission, granted, denied, answered)`` rows.
    """
    print("\nPERMISSIONS               asked   granted   denied")
    if not rows:
        print("  (nobody has been asked yet)")
        return
    by_name = {r[0]: r for r in rows}
    for name in PERMISSIONS:
        row = by_name.get(name)
        if row is None:
            continue
        _, granted, denied, answered = row
        print(f"  {name:<22} {answered:>7}   {pct(granted, answered):>7}"
              f"   {pct(denied, answered):>6}")


def print_usage(row) -> None:
    """Prints sign-ins, session length, and the deliberate ways people leave.

    Retention says someone stopped coming back. These lines say whether they
    chose to go (deleted the account, left a group) or simply could not get
    back in, which are opposite problems with opposite fixes.

    :param row: the single result row from :func:`build_usage_query`.
    """
    signed_in, failed, unfriended, left_group, deleted, session_ms = row
    attempts = signed_in + failed
    print("\nSIGNING IN & LEAVING       people")
    print(f"  {'Signed in':<22} {signed_in:>7}")
    print(f"  {'Sign-in failed':<22} {failed:>7}   "
          f"{pct(failed, attempts)} of attempts")
    print(f"  {'Removed a friend':<22} {unfriended:>7}")
    print(f"  {'Left a group':<22} {left_group:>7}")
    print(f"  {'Deleted their account':<22} {deleted:>7}")
    print(f"  {'Median session':<22} {human_ms(session_ms):>7}")


def main(argv=None) -> int:
    """Runs the four queries and prints the digest.

    :param argv: argument list, defaulting to ``sys.argv[1:]``.
    :return: process exit code (0 ok, 1 query error, 2 missing key).
    """
    parser = argparse.ArgumentParser(
        description="PostHog growth digest (read-only).")
    parser.add_argument("--env", default="production",
                        choices=["staging", "production"],
                        help="analytics_env to report (default: production).")
    parser.add_argument("--days", type=int, default=30,
                        help="look-back window in days (default: 30).")
    args = parser.parse_args(argv)

    key = os.environ.get("POSTHOG_READONLY_KEY", "").strip()
    if not key:
        print("error: POSTHOG_READONLY_KEY is not set (read-only key).",
              file=sys.stderr)
        return 2
    host = os.environ.get("POSTHOG_HOST", DEFAULT_HOST).rstrip("/")
    project = os.environ.get("POSTHOG_PROJECT_ID", DEFAULT_PROJECT)

    queries = {
        "funnel": build_funnel_query(args.env, args.days),
        "walkthrough": build_walkthrough_query(args.env, args.days),
        "country": build_country_query(args.env, args.days),
        "permissions": build_permission_query(args.env, args.days),
        "usage": build_usage_query(args.env, args.days),
        "retention": build_retention_query(args.env),
    }
    results = {}
    for name, hogql in queries.items():
        try:
            results[name] = (run_query(host, project, key, hogql)
                             .get("results") or [])
        except urllib.error.HTTPError as e:
            print(f"error: {name} query failed ({e.code}): "
                  f"{e.read().decode()[:300]}", file=sys.stderr)
            return 1
        except urllib.error.URLError as e:
            print(f"error: could not reach PostHog: {e.reason}",
                  file=sys.stderr)
            return 1

    print(f"Reacti growth digest  |  env={args.env}  |  last {args.days}d")
    print("=" * 62)
    if not results["funnel"]:
        print(f"No events for env={args.env} in the last {args.days}d.")
        return 0
    print_funnel(results["funnel"][0])
    if results["walkthrough"]:
        print_walkthrough(results["walkthrough"][0])
    print_countries(results["country"])
    print_permissions(results["permissions"])
    if results["usage"]:
        print_usage(results["usage"][0])
    if results["retention"]:
        print_retention(results["retention"][0])
    print("=" * 62)
    print("read-only; counts and medians only, never an individual.")
    print("invite loop is server-side: php artisan invites:digest")
    return 0


if __name__ == "__main__":
    sys.exit(main())
