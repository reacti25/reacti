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
    return f"{round(100 * a / b)}%" if b else ""


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


# Site palette (insights_template.html). Email clients ignore <style> and CSS
# variables, so everything is inline and laid out with tables.
INK, MUTED, FAINT, LINE, BG, SOFT, BRAND, HERO = "#0E100C", "#5F6359", "#8C9086", "#E4E6E0", "#F6F7F4", "#F1F2EE", "#CDF03A", "#16190F"
FONT = "-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"


def tiles(nums: list[int], labels: list[str], hero: bool = False) -> str:
    """One row of number tiles. A funnel row shows the share between
    neighbours; the hero row is separate numbers, so it only gets a gap."""
    bg, fg, sub = ("#262B1C", "#FFFFFF", "#A9AE9F") if hero else (SOFT, INK, MUTED)
    cells = []
    for i, (n, label) in enumerate(zip(nums, labels)):
        if i:
            cells.append('<td width="8" style="font-size:0">&nbsp;</td>' if hero else
                         f'<td align="center" style="padding:0 2px;color:{FAINT};font:12px {FONT}">&rarr;<br>{pct(n, nums[i - 1])}</td>')
        cells.append(f'<td align="center" width="{32 if hero else 22}%" style="background:{bg};border-radius:12px;padding:14px 4px">'
                     f'<div style="font:700 26px {FONT};color:{fg}">{n}</div>'
                     f'<div style="font:12px/1.3 {FONT};color:{sub};padding-top:4px">{html.escape(label)}</div></td>')
    return f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>{"".join(cells)}</tr></table>'


def card(head: str, rows: list[tuple[str, str, str]]) -> str:
    """A white section card: the topic, its question, then label/value rows."""
    topic, _, question = head.partition(": ")
    question = question[:1].upper() + question[1:]
    body = "".join(
        f'<tr><td style="padding:12px 0;border-top:1px solid {LINE};font:14px/1.4 {FONT};color:{INK}">{html.escape(l)}</td>'
        f'<td align="right" style="padding:12px 0 12px 12px;border-top:1px solid {LINE};white-space:nowrap;vertical-align:top">'
        f'<div style="font:700 16px {FONT};color:{INK}">{html.escape(a)}</div>'
        + (f'<div style="font:12px {FONT};color:{FAINT};padding-top:2px">week before: {html.escape(b)}</div>' if b else "")
        + "</td></tr>" for l, a, b in rows)
    return (f'<tr><td style="padding:0 0 14px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
            f'style="background:#FFFFFF;border:1px solid {LINE};border-radius:14px"><tr><td style="padding:18px 20px 6px">'
            f'<div style="font:700 11px {FONT};letter-spacing:1px;text-transform:uppercase;color:{MUTED}">{html.escape(topic)}</div>'
            f'<div style="font:600 16px/1.35 {FONT};color:{INK};padding:4px 0 10px">{html.escape(question)}</div>'
            f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0">{body}</table></td></tr></table></td></tr>')


def render(d: dict) -> tuple[str, str, str]:
    """(subject, html, text) for one week's email."""
    p = d["product"]
    subject = (f"Reacti weekly: {p['new_accounts'][0]} new accounts, {p['reactis'][0]['sent']} Reactis, "
               f"{p['reactis'][0]['reacted']} with a reaction back")
    r = p["reactis"][0]
    hero = tiles([p["new_accounts"][0], r["sent"], r["reacted"]], ["New accounts", "Reactis sent", "Got a reaction back"], hero=True)
    text = [subject, "", "Where people stop (accounts from the last 90 days): "
            + " -> ".join(f"{n} {s}" for n, s in zip(p["strip"]["d90"], STEPS)), ""]
    cards = []
    for head, rows in sections(d):
        cards.append(card(head, rows))
        text += [head] + [f"  {l}: {a}" + (f" (week before: {b})" if b else "") for l, a, b in rows] + [""]
    label = f'font:700 11px {FONT};letter-spacing:1px;text-transform:uppercase;color:{MUTED};padding:0 0 10px'
    page = (
        f'<div style="background:{BG};padding:24px 12px"><table role="presentation" align="center" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px">'
        # Header
        f'<tr><td style="padding:0 0 16px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{HERO};border-radius:16px">'
        f'<tr><td style="padding:22px 22px 8px"><span style="display:inline-block;background:{BRAND};color:{HERO};font:700 12px {FONT};padding:4px 10px;border-radius:99px">Reacti Insights</span>'
        f'<div style="font:700 22px/1.3 {FONT};color:#FFFFFF;padding-top:12px">The week in numbers</div>'
        f'<div style="font:13px {FONT};color:#A9AE9F;padding:4px 0 14px">Last 7 days</div></td></tr>'
        f'<tr><td style="padding:0 16px 18px">{hero}</td></tr></table></td></tr>'
        # Funnel
        f'<tr><td style="padding:0 0 14px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FFFFFF;border:1px solid {LINE};border-radius:14px">'
        f'<tr><td style="padding:18px 16px">'
        f'<div style="{label}">Where people stop &middot; accounts from the last 90 days</div>{tiles(p["strip"]["d90"], STEPS)}'
        f'<div style="{label};padding-top:18px">All accounts ever</div>{tiles(p["strip"]["all"], STEPS)}'
        f'</td></tr></table></td></tr>'
        + "".join(cards) +
        # Footer
        f'<tr><td align="center" style="padding:8px 0 4px"><a href="{SITE}" style="display:inline-block;background:{BRAND};color:{HERO};'
        f'font:700 14px {FONT};text-decoration:none;padding:12px 22px;border-radius:99px">Open the full dashboard</a></td></tr>'
        f'<tr><td align="center" style="padding:12px 0 0;font:12px {FONT};color:{FAINT}">Data as of {html.escape(d["generated_at"])}</td></tr>'
        f'</table></div>')
    foot = f"Full dashboard: {SITE} · data as of {d['generated_at']}"
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
