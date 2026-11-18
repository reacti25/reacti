#!/usr/bin/env python3
"""Self-check for ``perf_digest.py`` - run it, don't import a framework.

There is no Python job in CI (see ``scripts/analytics/README.md``), so this is
a plain assert script:

    python scripts/analytics/test_perf_digest.py

It covers the parts that can quietly produce a wrong number rather than an
error: the percentage denominators, the split between a real crash and an
error the app survived, and the per-phone query's grouping.
"""
import sys

import perf_digest as p


def test_pct_handles_empty_denominators() -> None:
    """Nothing to divide by reads 'n/a', never a division error or a 0%."""
    assert p.pct(5, 0) == "n/a"
    assert p.pct(5, None) == "n/a"
    assert p.pct(None, 200) == "0.0%"
    assert p.pct(15, 200) == "7.5%"


def test_only_an_unhandled_non_dart_error_is_a_crash() -> None:
    """A Dart error the app survived must not be counted as a crash."""
    assert not p.is_real_crash(["PlatformDispatcher.onError"], 0)
    assert not p.is_real_crash(["FlutterError"], 0)
    assert p.is_real_crash(["mach"], 0)
    # A mechanism nobody listed is treated as a crash: better a false alarm.
    assert p.is_real_crash(["something_new"], 0)
    assert p.is_real_crash([], 0)
    # A handled error is never a crash, whatever reported it.
    assert not p.is_real_crash(["mach"], 1)


def test_device_query_groups_by_model_only_when_asked() -> None:
    """The OS view must not split by model, and the model view must."""
    by_os = p.build_device_query("production", 30, by_model=False)
    by_model = p.build_device_query("production", 30, by_model=True)
    assert "'all' as model" in by_os
    assert "$device_model" not in by_os
    assert "properties.$device_model as model" in by_model
    for query in (by_os, by_model):
        assert "properties.analytics_env = 'production'" in query
        assert "toIntervalDay(30)" in query


def test_device_line_shows_na_for_versions_without_the_split() -> None:
    """Old app versions report no build/raster split: 'n/a', not '0.0%'."""
    line = p.device_line(
        ["Android", "SM-A566B", 2, 1000.0, 50.0, 0.0, 0.0, 0.0, 94.0, 142.0, 200.0])
    assert "5.0%" in line  # 50 of 1000 frames over the fixed 16 ms
    assert line.count("n/a") == 2  # slow build, slow draw


def test_error_line_carries_the_verdict() -> None:
    """Each error row says whether the app crashed or kept running."""
    survived = p.error_line({"title": "TypeError: x", "os.name": "Android",
                             "error.handled": 0, "count()": 7,
                             "count_unique(user)": 2,
                             "error.mechanism": ["PlatformDispatcher.onError"]})
    crashed = p.error_line({"title": "EXC_BAD_ACCESS", "os.name": "iOS",
                            "error.handled": 0, "count()": 1,
                            "count_unique(user)": 1,
                            "error.mechanism": ["mach"]})
    assert "kept running" in survived and "CRASH" not in survived
    assert "CRASH" in crashed


def main() -> int:
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for test in tests:
        test()
        print(f"ok  {test.__name__}")
    print(f"{len(tests)} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
