"""Self-check for insights_site.py's maths and plain-language notes (no network).

    python scripts/analytics/test_insights_site.py
"""
import datetime as dt
import unittest

import insights_site as s

T = dt.date(2026, 10, 17)


def day(n):  # n days before T
    return T - dt.timedelta(days=n)


# a: active every day for 3 weeks. b: new this week. c: active last week only. d: back after a gap.
ACTIVITY = {
    "a": {day(i) for i in range(21)},
    "b": {day(1)},
    "c": {day(9)},
    "d": {day(30), day(2)},
}
FIRST = {p: min(ds) for p, ds in ACTIVITY.items()}


class MathsTest(unittest.TestCase):
    def test_growth_accounting_splits_new_retained_resurrected_churned(self):
        w = s.growth_accounting(ACTIVITY, FIRST, T, weeks=2)[-1]
        self.assertEqual((w["new"], w["retained"], w["resurrected"], w["churned"]), (1, 1, 1, 1))
        self.assertEqual(w["quick_ratio"], 2.0)  # (1 new + 1 back) / 1 lost

    def test_power_curve_counts_days_active(self):
        self.assertEqual(s.power_curve(ACTIVITY, T, 7), [2, 0, 0, 0, 0, 0, 1])  # b,d once; a every day

    def test_rolling_retention_only_counts_people_old_enough(self):
        r = {x["day"]: x for x in s.rolling_retention(ACTIVITY, FIRST, T)}
        self.assertEqual((r[1]["eligible"], r[1]["kept"]), (4, 2))   # a and d came back
        self.assertEqual((r[30]["eligible"], r[30]["kept"]), (1, 0))  # only d is 30+ days old; back on day 28

    def test_stickiness_is_average_dau_over_mau(self):
        da = s.daily_active({"x": {T}, "y": {day(i) for i in range(28)}}, T, days=1)
        self.assertEqual(da["mau"][-1], 2)
        self.assertEqual(da["stickiness"][-1], round(100 * (29 / 28) / 2, 1))

    def test_monthly_splits_by_calendar_month_and_marks_this_one_partial(self):
        counts = {"signup_completed": {dt.date(2026, 9, 30): 2, dt.date(2026, 10, 1): 3}}
        rows = s.monthly(ACTIVITY, counts, T, months=2)
        self.assertEqual([(r["month"], r["signups"], r["partial"]) for r in rows], [("2026-09", 2, False), ("2026-10", 3, True)])
        self.assertEqual((rows[0]["active"], rows[1]["active"]), (2, 4))  # Sep: a, d. Oct: everyone
        self.assertIsNone(rows[0]["reactis"])  # never recorded: "not measured", not zero

    def test_monthly_drops_months_before_any_data(self):
        self.assertEqual([r["month"] for r in s.monthly(ACTIVITY, {}, T, months=4)], ["2026-09", "2026-10"])

    def test_month_starts_cross_the_year(self):
        self.assertEqual(s.month_starts(dt.date(2027, 2, 10), 3), [dt.date(2026, 12, 1), dt.date(2027, 1, 1), dt.date(2027, 2, 1)])

    def test_funnel_ignores_existing_users(self):
        steps = [("Opened", None), ("Tried the demo", "demo_started")]
        f = s.funnel_new_only(steps, {"demo_started": {"old", "new1"}}, {"new1", "new2"})
        self.assertEqual([x["value"] for x in f], [2, 1])

    def test_ratings_are_weighted_by_count(self):
        r = s.merge_ratings({"IL": (5, 3), "US": (3, 1), "GB": (0, 0)})
        self.assertEqual((r["average"], r["count"]), (4.5, 4))
        self.assertEqual([c["label"] for c in r["countries"]], ["IL", "US"])

    def test_sales_report_counts_only_first_downloads(self):
        tsv = ("Provider\tProduct Type Identifier\tUnits\tCountry Code\n"
               "APPLE\t1F\t3\tIL\nAPPLE\t7F\t9\tIL\nAPPLE\t1F\t2\tUS\nAPPLE\t3F\t4\tUS\n")
        units, by_country = s.parse_sales_tsv(tsv)
        self.assertEqual(units, 5)
        self.assertEqual(dict(by_country), {"IL": 3, "US": 2})


def data(**over):
    base = {
        "kpis": {"stickiness": [8.0, 8.0], "mau": [18, 15]},
        "growth": [{"new": 1, "resurrected": 1, "churned": 4, "quick_ratio": 0.5}],
        "retention": [{"day": 1, "eligible": 50, "kept": 5, "pct": 10, "benchmark": 30}],
        "funnel": [{"label": "Created account", "value": 10}, {"label": "Sent a first Reacti", "value": 2},
                   {"label": "Got a first reaction back", "value": 2}],
        "loop": {"opened": 0, "returned": 0, "text": 0, "media": 0},
        "network": {"invites_opened": 0, "invites_joined": 0},
        "quality": {"login_ok": 8, "login_fail": 13, "login_reasons": [{"label": "http_4xx", "value": 9}],
                    "media_p90_s": 0.4, "api_error_pct": 0.5, "permissions": []},
    }
    base.update(over)
    return base


class InsightsTest(unittest.TestCase):
    def titles(self, d):
        return [n["title"] for n in s.insights(d)]

    def test_critical_findings_come_first(self):
        levels = [n["level"] for n in s.insights(data())]
        self.assertEqual(levels, sorted(levels, key=["critical", "warning", "info", "good"].index))

    def test_flags_a_shrinking_base(self):
        self.assertTrue(any("shrinking" in t for t in self.titles(data())))

    def test_flags_the_biggest_activation_drop(self):
        self.assertTrue(any("“Created account” and “Sent a first Reacti”" in t for t in self.titles(data())))

    def test_flags_sign_in_failures_with_reason(self):
        note = next(n for n in s.insights(data()) if "sign-in" in n["title"])
        self.assertIn("62%", note["title"])
        self.assertIn("http 4xx", note["detail"])

    def test_flags_crashes(self):
        q = {**data()["quality"], "crash_free": {"7d": {"pct": 90, "users": 10}, "30d": {"pct": 60, "users": 20}}}
        note = next(n for n in s.insights(data(quality=q)) if "crash" in n["title"])
        self.assertEqual((note["level"], note["title"]), ("critical", "Only 60% of people used the app without a crash"))

    def test_small_samples_are_marked_early(self):
        note = next(n for n in s.insights(data()) if "sign-in" in n["title"])
        self.assertTrue(note["early"])  # 21 attempts
        ret = next(n for n in s.insights(data()) if "Day-1" in n["title"])
        self.assertFalse(ret["early"])  # 50 people

    def test_quiet_when_nothing_is_wrong(self):
        calm = data(growth=[], retention=[], kpis={"stickiness": [30, 30], "mau": [100, 90]},
                    funnel=[{"label": "Created account", "value": 0}],
                    quality={"login_ok": 20, "login_fail": 1, "login_reasons": [], "media_p90_s": 0.4,
                             "api_error_pct": 0.1, "permissions": []})
        self.assertEqual(s.insights(calm), [])


if __name__ == "__main__":
    unittest.main()
