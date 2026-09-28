#!/usr/bin/env python3
"""Self-check for ``growth_digest.py`` - run it, don't import a framework.

There is no Python job in CI (see ``scripts/analytics/README.md``), so this is
a plain assert script:

    python scripts/analytics/test_growth_digest.py

It covers the parts that can quietly produce a wrong number rather than an
error: percentage denominators, duration formatting, and the retention query's
eligibility filter - the one that decides whether someone who installed
yesterday counts against D30.
"""
import re
import sys

import growth_digest as g


def test_pct_handles_empty_denominators() -> None:
    """A zero or missing denominator reads 'n/a' rather than dividing by zero."""
    assert g.pct(0, 0) == "n/a"
    assert g.pct(5, None) == "n/a"
    assert g.pct(None, 10) == "0%"
    assert g.pct(1, 3) == "33%"
    assert g.pct(10, 10) == "100%"


def test_human_ms_picks_a_sensible_unit() -> None:
    """Time-to-value spans seconds to weeks, so the unit has to move with it."""
    assert g.human_ms(None) == "-"
    assert g.human_ms(45_000) == "45s"
    assert g.human_ms(600_000) == "10m"
    assert g.human_ms(7_200_000) == "2h"
    assert g.human_ms(259_200_000) == "3.0d"


def test_retention_query_excludes_the_too_new() -> None:
    """D7 must not count someone who arrived yesterday as lost.

    The eligibility clause is the whole point of the query; without it the
    retention numbers fall as the app grows, which reads as a collapse.
    """
    sql = g.build_retention_query("production")
    for day in g.RETENTION_DAYS:
        assert f"first_seen <= now() - toIntervalDay({day})" in sql
        assert f"last_seen >= first_seen + toIntervalDay({day})" in sql
    assert f"toIntervalDay({g.RETENTION_COHORT_DAYS})" in sql


def test_funnel_follows_a_cohort_rather_than_counting_each_step() -> None:
    """A later step must not be able to hold people the earlier one never had.

    The original query counted, per step, everyone who fired that event inside
    the window. That is not a funnel: someone who signed up in August and sent
    their first Reacti last week landed in the later step and not the earlier
    one, and the first real production run printed 125% and 300% conversion.
    The cohort is now fixed by first-ever appearance, and every step asks about
    those same people.
    """
    sql = g.build_funnel_query("staging", 30)
    assert "min(timestamp) as first_seen" in sql
    assert "having first_seen >= now() - toIntervalDay(30)" in sql
    # The cohort scan must reach back further than the window, or someone
    # returning after a long gap reads as a new arrival.
    assert f"toIntervalDay({g.COHORT_LOOKBACK_DAYS})" in sql
    assert g.COHORT_LOOKBACK_DAYS > 30
    assert "properties.analytics_env = 'staging'" in sql


def test_funnel_counts_people_not_events() -> None:
    """One person opening the app forty times is one person."""
    sql = g.build_funnel_query("staging", 30)
    assert "count()" not in sql
    for i, _ in enumerate(g.FUNNEL):
        assert f"countIf(s{i} > 0) as n{i}" in sql


def test_no_query_reuses_an_inner_alias_in_its_outer_select() -> None:
    """HogQL rejects a repeated alias as an aggregate inside an aggregate.

    This is the bug that took the walkthrough section down on the first real
    run: the outer `as saw` collided with the inner `as saw`, and the string
    assertions above it all passed while the query itself was rejected with a
    400. Checking for the collision is the cheapest stand-in for a query the
    tests cannot actually execute.
    """
    for sql in (
        g.build_funnel_query("staging", 30),
        g.build_walkthrough_query("staging", 30),
        g.build_retention_query("staging"),
        g.build_permission_query("staging", 30),
    ):
        aliases = re.findall(r"\bas (\w+)", sql)
        assert len(aliases) == len(set(aliases)), (
            f"duplicate alias in query: "
            f"{[a for a in aliases if aliases.count(a) > 1]}"
        )


def test_walkthrough_query_groups_by_person_first() -> None:
    """The comparison is people-to-people, not a ratio of raw event counts."""
    sql = g.build_walkthrough_query("production", 30)
    assert "group by person_id" in sql
    assert "countIf(saw > 0 and activated > 0)" in sql


def test_permission_query_takes_each_persons_latest_answer() -> None:
    """Someone who denies then allows must not land in both buckets.

    Counting raw events would do exactly that, and would understate the denial
    rate, which is the number this section exists to report honestly.
    """
    sql = g.build_permission_query("production", 30)
    assert "argMax(properties.result, timestamp)" in sql
    assert "group by person_id, permission" in sql
    assert "event = 'permission_result'" in sql


def test_usage_query_counts_people_per_outcome() -> None:
    """Sign-ins, leaving and session length all count distinct people."""
    sql = g.build_usage_query("staging", 7)
    for event in ("login_result", "friend_removed", "group_left",
                  "account_deleted"):
        assert event in sql
    assert "uniqIf(person_id" in sql
    assert "properties.elapsed_ms" in sql


def main() -> int:
    """Runs every ``test_*`` in this module and reports.

    :return: 0 when all pass, 1 on the first failure.
    """
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for test in tests:
        try:
            test()
        except AssertionError:
            print(f"FAIL {test.__name__}")
            raise
        print(f"ok   {test.__name__}")
    print(f"\n{len(tests)} passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
