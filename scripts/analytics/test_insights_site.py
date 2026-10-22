"""Self-check for insights_site.py's maths (no network).

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

    def test_funnel_follows_new_accounts(self):
        steps = [("Opened", None), ("Started", "register_started"), ("Created", "signup_completed"),
                 ("Demo", "demo_started")]
        people = {"register_started": {"a", "old"}, "signup_completed": {"a", "b"},
                  "demo_started": {"a", "b", "c", "old"}}
        f = s.funnel_new_only(steps, people, {"a", "b", "c", "d"})
        # b's retry skipped "Started"; c took the demo on an account made before analytics; old isn't new
        self.assertEqual([x["value"] for x in f], [4, 2, 2, 2])

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


# Journeys as the backend returns them: sent = [date, opened, reacted, watched].
def iso(n):
    return str(day(n))


JOURNEYS = [
    # Sent on day 1 after joining, got a reaction, sent again later: all three steps.
    {"joined": iso(40), "sent": [[iso(39), 1, 1, 1], [iso(3), 1, 0, 0]], "first_received": None},
    # Received first, then sent: a recipient who became a sender. Reaction came back, never sent again.
    {"joined": iso(20), "sent": [[iso(10), 1, 1, 0]], "first_received": iso(18)},
    # Received, never sent. Joined this week.
    {"joined": iso(2), "sent": [], "first_received": iso(1)},
    # Sent once, nobody opened it. Joined 200 days ago.
    {"joined": iso(200), "sent": [[iso(190), 0, 0, 0]], "first_received": None},
]


class ProductTest(unittest.TestCase):
    def setUp(self):
        self.p = s.product(JOURNEYS, T)

    def test_journey_steps_need_a_send_after_the_first_reaction(self):
        self.assertEqual(s.journey_steps(JOURNEYS[0]), (True, True, True))
        self.assertEqual(s.journey_steps(JOURNEYS[1]), (True, True, False))
        # Same-day second send is not "coming back".
        self.assertEqual(s.journey_steps({"sent": [[iso(5), 1, 1, 0], [iso(5), 0, 0, 0]]}), (True, True, False))

    def test_strip_counts_people_at_each_step(self):
        self.assertEqual(self.p["strip"]["all"], [4, 3, 2, 1])
        self.assertEqual(self.p["strip"]["d90"], [3, 2, 2, 1])

    def test_weekly_pairs_split_this_week_from_last(self):
        self.assertEqual(self.p["new_accounts"], [1, 0])
        self.assertEqual(self.p["reactis"][0], {"sent": 1, "opened": 1, "reacted": 0, "watched": 0})
        self.assertEqual(self.p["reactis"][1]["sent"], 1)  # day 10
        self.assertEqual(self.p["senders"], [1, 1])
        self.assertEqual(self.p["repeat_senders"], [1, 0])  # the day-3 sender had sent on day 39

    def test_activation_counts_a_send_within_7_days_of_joining(self):
        # Joined 40 and 20 days ago are eligible (day-2 account is too young, day-200 too old).
        self.assertEqual(self.p["activation"], {"eligible": 2, "sent_7d": 1})

    def test_organic_counts_recipients_who_sent_after_receiving(self):
        self.assertEqual(self.p["organic"], {"recipients": 2, "became_senders": 1})
        self.assertEqual(self.p["multi_day"], [1, 3])
        self.assertEqual(self.p["total_users"], 4)

    def test_email_renders_from_the_product_numbers(self):
        import insights_email
        subject, page, text = insights_email.render({"product": self.p, "kpis": {}, "generated_at": "now"})
        self.assertEqual(subject, "Reacti weekly: 1 new accounts, 1 Reactis, 0 with a reaction back")
        self.assertIn("Reaction watched by the sender: 0 (week before: 0 of 1 (0%))", text)  # no reactions this week: no 0-of-0 share
        self.assertIn("reacti-insights.pages.dev", page)


if __name__ == "__main__":
    unittest.main()
