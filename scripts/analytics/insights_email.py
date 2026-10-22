"""Weekly "Reacti Insights" email: the Product validation numbers, this week
against the week before, with a link to the dashboard. Sent by
.github/workflows/insights-email.yml every Monday through Resend.

Reads the data.json the hourly site build publishes next to the page, so it
needs no analytics or database keys. Statistics only, like the site.

Usage:
    RESEND_API_KEY=re_... INSIGHTS_EMAIL_TO="a@x.com,b@y.com" python scripts/analytics/insights_email.py
    python scripts/analytics/insights_email.py --dry-run out.html   # render only, send nothing

Env:
    RESEND_API_KEY      Resend API key with sending access on reacti.io.
    INSIGHTS_EMAIL_TO   comma-separated recipients (a GitHub variable).
    INSIGHTS_DATA_URL   default https://reacti-insights.pages.dev/data.json
"""
from __future__ import annotations

import argparse
import html
import json
import os
import sys
import urllib.error
import urllib.request

SITE = "https://reacti-insights.pages.dev"
DATA_URL = os.environ.get("INSIGHTS_DATA_URL", f"{SITE}/data.json")
FROM = "Reacti Insights <insights@reacti.io>"
STEPS = ["Joined", "Sent a Reacti", "Got a reaction back", "Sent another after that"]


def pct(a: int, b: int) -> str:
    return f"{round(100 * a / b)}%" if b else "–"


def of(a: int, b: int) -> str:
    return f"{a} of {b} ({pct(a, b)})" if b else str(a)


def sections(d: dict) -> list[tuple[str, list[tuple[str, str, str]]]]:
    """(heading, [(label, this week, week before)]) blocks. Empty week-before cells are cumulative numbers."""
    p, k = d["product"], d["kpis"]
    r, rp = p["reactis"]
    acq = [("Registered users, all time", str(p["total_users"]), ""),
           ("New accounts", str(p["new_accounts"][0]), str(p["new_accounts"][1]))]
    if k.get("downloads"):
        acq.append(("App Store downloads", str(k["downloads"][0]), str(k["downloads"][1])))
    return [
        ("Acquisition: are new users joining?", acq),
        ("Activation: are they sending their first Reacti?", [
            ("Sent a Reacti within 7 days of joining (accounts 7 to 97 days old)", of(p["activation"]["sent_7d"], p["activation"]["eligible"]), "")]),
        ("Core experience: are Reactis opened, reacted to and watched?", [
            ("Reactis sent", str(r["sent"]), str(rp["sent"])),
            ("Opened by the friend", of(r["opened"], r["sent"]), of(rp["opened"], rp["sent"])),
            ("Got a reaction back", of(r["reacted"], r["sent"]), of(rp["reacted"], rp["sent"])),
            ("Reaction watched by the sender", of(r["watched"], r["reacted"]), of(rp["watched"], rp["reacted"]))]),
        ("Retention: do people send another Reacti?", [
            ("People who sent a Reacti", str(p["senders"][0]), str(p["senders"][1])),
            ("… of them had sent one before", of(p["repeat_senders"][0], p["senders"][0]), of(p["repeat_senders"][1], p["senders"][1])),
            ("Got a reaction back, then sent another (all time)", of(p["strip"]["all"][3], p["strip"]["all"][2]), "")]),
        ("Organic growth: are recipients becoming senders?", [
            ("Received a Reacti before sending one, then sent their own (all time)",
             of(p["organic"]["became_senders"], p["organic"]["recipients"]), "")]),
    ]


def render(d: dict) -> tuple[str, str, str]:
    """(subject, html, text) for one week's email."""
    p = d["product"]
    subject = (f"Reacti weekly: {p['new_accounts'][0]} new accounts, {p['reactis'][0]['sent']} Reactis, "
               f"{p['reactis'][0]['reacted']} with a reaction back")
    e = html.escape
    td = 'style="padding:6px 8px;border-bottom:1px solid #eee;text-align:right;white-space:nowrap"'
    strip = " &rarr; ".join(f"<b>{n}</b> {s}" for n, s in zip(p["strip"]["d90"], STEPS))
    body = [f'<p style="color:#555">Where people stop, accounts created in the last 90 days:<br>{strip}</p>']
    text = [subject, "", "Where people stop (accounts from the last 90 days): "
            + " -> ".join(f"{n} {s}" for n, s in zip(p["strip"]["d90"], STEPS)), ""]
    for head, rows in sections(d):
        body.append(f'<h3 style="margin:22px 0 6px;font-size:15px">{e(head)}</h3><table style="border-collapse:collapse;width:100%;font-size:14px">'
                    f'<tr><th></th><th {td}>Last 7 days</th><th {td}>Week before</th></tr>'
                    + "".join(f'<tr><td style="padding:6px 8px 6px 0;border-bottom:1px solid #eee">{e(l)}</td><td {td}><b>{e(a)}</b></td><td {td}>{e(b)}</td></tr>'
                              for l, a, b in rows) + "</table>")
        text += [head] + [f"  {l}: {a}" + (f" (week before: {b})" if b else "") for l, a, b in rows] + [""]
    foot = f"Full dashboard: {SITE} · data as of {d['generated_at']}"
    page = (f'<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:640px;color:#111">'
            f'<h2 style="margin:0 0 4px">Reacti, the week in numbers</h2>{"".join(body)}'
            f'<p style="margin-top:24px;color:#555"><a href="{SITE}">Open the full dashboard</a> · data as of {e(d["generated_at"])}</p></div>')
    return subject, page, "\n".join(text + [foot])


def send(key: str, to: str, subject: str, page: str, text: str) -> None:
    """One email per recipient, so nobody sees the others' addresses."""
    req = urllib.request.Request("https://api.resend.com/emails", method="POST",
                                 data=json.dumps({"from": FROM, "to": [to], "subject": subject, "html": page, "text": text}).encode(),
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json", "User-Agent": "reacti-insights/1"})
    with urllib.request.urlopen(req, timeout=30) as r:
        print(f"sent to {to}: {r.status}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", metavar="OUT", help="write the HTML here and send nothing")
    args = ap.parse_args()

    with urllib.request.urlopen(urllib.request.Request(DATA_URL, headers={"User-Agent": "reacti-insights/1"}), timeout=30) as r:
        data = json.loads(r.read())
    if not data.get("product"):
        print("error: the dashboard has no Product validation numbers yet (database feed not configured)", file=sys.stderr)
        return 1
    subject, page, text = render(data)
    if args.dry_run:
        with open(args.dry_run, "w", encoding="utf-8") as f:
            f.write(page)
        print(subject)
        print(text)
        return 0

    key = os.environ.get("RESEND_API_KEY", "").strip()
    recipients = [a.strip() for a in os.environ.get("INSIGHTS_EMAIL_TO", "").split(",") if a.strip()]
    if not key or not recipients:
        print("error: RESEND_API_KEY and INSIGHTS_EMAIL_TO must be set", file=sys.stderr)
        return 2
    failed = 0
    for to in recipients:
        try:
            send(key, to, subject, page, text)
        except urllib.error.URLError as e:  # keep going: one bad address must not stop the others
            print(f"failed for {to}: {e}", file=sys.stderr)
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
