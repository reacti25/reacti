# Free CDN via Cloudflare — staging first, then production

**Goal:** put a free global CDN in front of Reacti's media so the *first* load
of a photo/video is fast for users far from the server. Re-views are already
instant (media has `expires max`); this only helps first loads at distance.

**Cost:** $0 — Cloudflare Free plan (DNS + CDN + TLS).
**Reversible:** yes, instantly (un-proxy a record, or point nameservers back).
**Server location:** Manchester, UK (Hostinger). Users far from the UK benefit
most; UK/EU users barely.

> Roles: steps marked **[Achia]** happen in Cloudflare / the domain registrar
> (Claude can't access those). Steps marked **[Claude]** are verifications
> Claude runs from the terminal after each **[Achia]** step. Do them in order;
> don't start a phase until the previous one is verified.

---

## Current DNS — the baseline to preserve (captured 2026-07-07)

| Type | Name | Value | Why it matters |
|------|------|-------|----------------|
| NS | reacti.io | ns1/ns2.dns-parking.com | today's DNS host (Hostinger) — we replace this |
| A | reacti.io | 72.61.202.136 | the site/API |
| A | www.reacti.io | 72.61.202.136 | the site |
| A | staging.reacti.io | 72.61.202.136 | staging (we flip this on FIRST) |
| MX | reacti.io | mx1/mx2.hostinger.com | **EMAIL — must survive the move** |
| TXT | reacti.io | `v=spf1 include:_spf.mail.hostinger.com ~all` | **email SPF — must survive** |

There may also be DKIM/`_dmarc` records for email — Cloudflare's scan should
import them; **we verify the imported set matches before switching** (Phase A).

Everything is on ONE server + ONE domain, so moving DNS to Cloudflare touches the
whole domain. We de-risk that by importing every record as **DNS-only (grey
cloud)** first — that changes nothing — and only then turning the CDN on for one
subdomain at a time.

---

## Phase A — Migrate DNS to Cloudflare with ZERO routing change

1. **[Achia]** Create a free account at cloudflare.com → **Add a site** →
   `reacti.io` → choose the **Free** plan.
2. **[Achia]** Cloudflare auto-scans and lists your existing DNS records. On the
   review screen, make sure **every record above is present** — especially the
   two **MX** rows and the **SPF TXT** row. Add any that are missing by hand
   (copy the values from the table). **Set every record's proxy status to
   "DNS only" (grey cloud) for now** — including the A records. Grey = no CDN
   yet = nothing changes.
3. **[Claude]** Verify the imported zone matches the baseline *before* you switch
   nameservers (Cloudflare shows the records; Claude re-checks MX/SPF/A resolve
   the same).
4. **[Achia]** Cloudflare gives you **two nameservers** (like
   `xxx.ns.cloudflare.com`). In your **domain registrar** (where reacti.io is
   registered), replace the current nameservers (`ns1/ns2.dns-parking.com`) with
   Cloudflare's two. Save.
5. **Wait** for activation — Cloudflare emails you when the domain is "Active"
   (usually minutes to a few hours).
6. **[Claude]** Confirm nameservers now point to Cloudflare, and that the site,
   API, and **email still work** (MX/SPF unchanged). Because all records are grey,
   the app should behave exactly as before.

**Gate:** do not proceed until the site loads, login works, and email is
verified working. If anything is off → registrar → set nameservers back to
`ns1/ns2.dns-parking.com` (full rollback).

---

## Phase B — Turn the CDN on for STAGING only

7. **[Achia]** In Cloudflare → **DNS** → the `staging.reacti.io` record → click
   the grey cloud so it turns **orange (Proxied)**. Save. (Leave `reacti.io` and
   `www` grey — production is untouched.)
8. **[Achia]** In Cloudflare → **SSL/TLS** → set encryption mode to
   **Full (strict)** (the origin already has a valid cert).
9. **[Claude]** Verify from the terminal:
   - staging media now returns a Cloudflare cache header
     (`cf-cache-status: HIT` on a second request to an image), and
   - the API path is passed through **un-cached** (dynamic responses must not be
     cached).
10. **[Achia — on the Reacti Staging app]** Full smoke test:
    - log in; open a chat; **send a photo and a video**;
    - as the recipient, **open a blurred media** → confirm the silent reaction
      still records and comes back (the patent flow);
    - images and videos load and play normally.

**Gate:** staging must be fully healthy — especially the open-media reaction
flow — before touching production. Rollback for staging = click the orange cloud
back to grey (instant).

> **Video note (free-tier terms):** Cloudflare's Free plan is meant for images
> and normal web assets, not heavy video delivery. Images are the frequent
> content and cache cleanly. If Cloudflare declines to cache video (or to stay
> clean on their terms), we add one **Cache Rule: bypass cache for `*.mp4`,
> `*.webm`** so video goes straight to the origin as it does today — still fine
> (video is already compressed + client-cached), and still $0.

---

## Phase C — Turn the CDN on for PRODUCTION

11. **[Achia]** Only after staging is signed off: in Cloudflare → **DNS** →
    turn `reacti.io` and `www.reacti.io` to **orange (Proxied)**.
12. **[Claude]** Verify prod media returns `cf-cache-status: HIT` on re-request
    and the API is passed through un-cached.
13. **[Achia — live app]** Quick smoke on the production App Store app: chat
    loads, media loads, open-media reaction records.

**Rollback (prod):** click the clouds back to grey (instant), or nameservers
back to Hostinger (full).

---

## What "done" looks like

- `curl -sI https://<host>/<some-image>` shows `cf-cache-status: HIT` (edge-cached).
- API/dynamic responses still show `cache-control: private, must-revalidate`.
- Email still sends/receives (MX/SPF intact).
- The open-media silent-reaction flow works on staging AND prod.
- Measured win: watch `media_load_ms` in PostHog for far-from-UK users drop.

## Notes

- No app or backend code changes — this is DNS/edge config only. Media URLs stay
  `reacti.io/...`; Cloudflare caches them at the edge transparently.
- Pusher realtime is a separate service (not on reacti.io), so the CDN doesn't
  touch it.
- If the measured win is negligible (most users near the UK), grey everything
  back — no cost sunk. See `reference-media-cache-headers-done` for why caching
  itself was already handled.
