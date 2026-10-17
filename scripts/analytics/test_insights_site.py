"""Self-check for insights_site.py's plain-language notes (no network).

    python scripts/analytics/test_insights_site.py
"""
import unittest

import insights_site as s


def data(**over):
    base = {
        "funnel": [
            {"label": "Signed up", "value": 6}, {"label": "Finished the demo", "value": 9},
            {"label": "Sent a first Reacti", "value": 5}, {"label": "Got a first reaction back", "value": 4},
        ],
        "logins": [{"label": "failure", "value": 13}, {"label": "success", "value": 8}],
        "kpis": {"reactis_30d": {"value": 10}, "reactions_30d": {"value": 5}},
        "failed_reactions": [],
    }
    base.update(over)
    return base


class InsightsTest(unittest.TestCase):
    def test_reports_first_reaction_share_of_signups(self):
        self.assertIn("6 sign-ups, and 4 people got their first reaction back", s.insights(data())[0])

    def test_singular_person_when_one_reacti_went_unanswered(self):
        self.assertTrue(any(n.startswith("1 person sent") for n in s.insights(data())))

    def test_flags_a_high_sign_in_failure_rate(self):
        self.assertTrue(any("62% of sign-in attempts fail" in n for n in s.insights(data())))

    def test_stays_quiet_about_sign_in_when_it_mostly_works(self):
        notes = s.insights(data(logins=[{"label": "failure", "value": 1}, {"label": "success", "value": 20}]))
        self.assertFalse(any("sign-in" in n for n in notes))

    def test_names_the_top_reaction_failure_cause(self):
        notes = s.insights(data(failed_reactions=[{"label": "permission_denied", "value": 3}]))
        self.assertTrue(any("permission_denied" in n and "3 reactions failed" in n for n in notes))

    def test_no_division_by_zero_without_activity(self):
        empty = data(funnel=[{"label": l, "value": 0} for l in
                             ("Signed up", "Finished the demo", "Sent a first Reacti", "Got a first reaction back")],
                     logins=[], kpis={"reactis_30d": {"value": 0}, "reactions_30d": {"value": 0}})
        self.assertEqual(s.insights(empty), [])


if __name__ == "__main__":
    unittest.main()
