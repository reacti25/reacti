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


def test_funnel_query_counts_people_not_events() -> None:
    """One person opening the app forty times is one person."""
    sql = g.build_funnel_query("staging", 30)
    assert "count()" not in sql
    for _, event in g.FUNNEL:
        assert f"uniqIf(person_id, event = '{event}')" in sql
    assert "properties.analytics_env = 'staging'" in sql


def test_walkthrough_query_groups_by_person_first() -> None:
    """The comparison is people-to-people, not a ratio of raw event counts."""
    sql = g.build_walkthrough_query("production", 30)
    assert "group by person_id" in sql
    assert "countIf(saw > 0 and activated > 0)" in sql


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
