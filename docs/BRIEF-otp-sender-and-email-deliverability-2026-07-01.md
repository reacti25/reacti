# BRIEF — OTP sender address + email deliverability

**Date:** 2026-07-01
**Author:** Achia (goal) + Claude (findings + plan)
**Status:** Decision + info-gathering brief. The code change is tiny; the real work is
DNS/deliverability and a provider decision. Blocked on two facts only Achia can get.
**Covers:** feature-list item **3** — "the email that sends the OTP has a weird, long,
suspicious-looking name; make it something simple like Reacti."

---

## 1. The problem

New users receive their signup OTP from an ugly, unfamiliar sender address. An
unrecognisable "from" looks like spam/phishing, hurts trust at the most fragile moment
(signup), and lands in spam folders. We want OTPs to come from something clean and
obviously-Reacti, e.g. **`Reacti <no-reply@reacti.io>`**.

---

## 2. What the code shows (and what it doesn't)

- OTP send paths:
  - **Signup OTP:** `backend/app/Services/AuthService.php` (≈L42–91) →
    `Mail::to($email)->send(new EmailVerifyMail(...))`; Mailable
    `backend/app/Mail/EmailVerifyMail.php`; template
    `backend/resources/views/emails/otpmail.blade.php`.
  - **Password-reset OTP:** `backend/app/Services/PasswordResetService.php`
    (≈L36–57, L183–198) → `OtpMail`; template `emails/passResetOtp.blade.php`.
- **Neither Mailable hardcodes a `from()`** — both inherit the global config in
  `backend/config/mail.php`:
  ```php
  'from' => [
      'address' => env('MAIL_FROM_ADDRESS', 'hello@example.com'),
      'name'    => env('MAIL_FROM_NAME', 'Example'),
  ],
  ```
- `.env.example` shows the *intended* values: `MAIL_FROM_ADDRESS="hello@reacti.io"`,
  `MAIL_FROM_NAME="${APP_NAME}"` (→ "Reacti"), `MAIL_MAILER=smtp`, host pointing at
  Mailtrap (dev only).

**Key point:** the ugly sender is **not in the repo**. The real value lives in the
**git-ignored production `backend/.env`** on the Hostinger VPS. Project memory says
production email goes via **AWS WorkMail** on the external **`climbiq-goonclimbers.com`**
domain — that is almost certainly the "weird long name." (Note: `climbiq-goonclimbers.com`
is also the self-hosted Reverb websocket host; it does double duty. Don't confuse the
two — this brief is about *email* only.)

So: **the fix is a config + DNS change, not a code change** (Laravel already reads the
sender from config). Code only changes if we choose to hardcode `from()` in the
Mailables as a belt-and-braces guard.

---

## 3. Two facts needed from Achia before proceeding

1. **The current production mail config.** Read `backend/.env` on the VPS and report:
   `MAIL_MAILER`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_ENCRYPTION`,
   `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`. (Do **not** paste passwords into the repo or
   chat — just the mailer/host/from fields.) This confirms exactly what's sending
   today and via which provider.
2. **Do we control DNS for `reacti.io`?** (Registrar + who hosts the zone — Hostinger,
   Cloudflare, etc.) We need to add authentication records there.

---

## 4. Why you can't "just change the From to reacti.io"

If you set `MAIL_FROM_ADDRESS=no-reply@reacti.io` but keep sending through a server
that isn't authorised for `reacti.io`, mailbox providers (Gmail especially) will mark
it spam or reject it, because **SPF/DKIM/DMARC won't line up**. Deliverability, not the
address string, is the actual work. There are two clean routes:

- **Route A — keep the current provider (e.g. WorkMail/SES), send *as* `reacti.io`.**
  Add `reacti.io` as a verified sending domain/identity in that provider, publish the
  provider's SPF include + DKIM CNAME(s) in the `reacti.io` DNS zone, add a DMARC
  record, then set `MAIL_FROM_ADDRESS=no-reply@reacti.io`. Lowest change, reuses infra.
- **Route B — move OTP to a transactional email provider** (Amazon SES, Postmark,
  Resend, Mailgun). These are built for OTP/transactional mail: better inbox
  placement, per-message logs, bounce/complaint handling. Verify `reacti.io`, publish
  their SPF/DKIM/DMARC, set SMTP creds in `.env`. Slightly more setup; best long-term
  reliability. **Recommended if OTP delivery has been flaky at all.**

Either way the app/user-facing result is identical: OTPs arrive from `Reacti
<no-reply@reacti.io>`.

---

## 5. Research / decision checklist

1. Get the two facts in §3.
2. Decide **Route A vs B**. Question to answer: has OTP delivery been unreliable (spam,
   delays)? If yes → lean B (transactional). If it's purely cosmetic and delivery is
   fine → A is cheaper.
3. Choose the exact sender identity: `no-reply@reacti.io` (recommended for automated
   mail) vs `hello@reacti.io` (already the config default; friendlier but usually
   reserved for human-monitored inboxes). Set `MAIL_FROM_NAME="Reacti"`.
4. Coordinate with **`docs/BRIEF-dns-and-media-performance-2026-07-01.md`** — SPF/DKIM/
   DMARC are DNS records; do the email DNS as part of the same DNS pass so the zone is
   touched once.

---

## 6. Implementation (once the route is chosen)

1. In the provider, verify the `reacti.io` sending domain and generate DKIM keys.
2. In the `reacti.io` DNS zone, publish:
   - **SPF** — a single `TXT` at the root with the provider's `include:` (merge, don't
     create a second SPF record).
   - **DKIM** — the provider's CNAME/TXT selector record(s).
   - **DMARC** — `_dmarc.reacti.io TXT "v=DMARC1; p=none; rua=mailto:dmarc@reacti.io"`
     to start (monitor), tighten to `quarantine`/`reject` later.
3. Update production `backend/.env`: `MAIL_MAILER`/`MAIL_HOST`/`MAIL_PORT`/creds for the
   chosen route, `MAIL_FROM_ADDRESS=no-reply@reacti.io`, `MAIL_FROM_NAME="Reacti"`.
   Keep `backend/.env.example` in sync (no secrets).
4. *(Optional hardening)* set `from()` explicitly in `EmailVerifyMail` and `OtpMail` so
   the sender is correct even if config is misread.
5. Update the OTP blade templates' branding/footer if they still show old/ugly info.

### Verify

- Send yourself a real signup OTP and a password-reset OTP; confirm the from-line reads
  **`Reacti <no-reply@reacti.io>`** in Gmail, Apple Mail, Outlook.
- Run the message through **mail-tester.com** (or Gmail "Show original") and confirm
  **SPF pass, DKIM pass, DMARC pass**.
- Confirm it lands in **Inbox**, not spam/Promotions, on a fresh Gmail account.
- No secrets committed; `.env.example` updated; `./vendor/bin/pint` clean if Mailables
  changed.

---

## 7. Effort & risk

Code: near-zero. DNS/provider: a few hours plus DNS propagation. Risk: **misconfiguring
SPF (two records) or DKIM breaks *all* outbound mail** — change carefully, test before
and after, and don't tighten DMARC to `reject` until SPF+DKIM are confirmed passing.

---

## 8. Key files index

- `backend/config/mail.php` — global `from` config.
- `backend/app/Mail/EmailVerifyMail.php`, `backend/app/Mail/OtpMail.php` — Mailables.
- `backend/resources/views/emails/otpmail.blade.php`,
  `backend/resources/views/emails/passResetOtp.blade.php` — templates.
- `backend/app/Services/AuthService.php`, `backend/app/Services/PasswordResetService.php`
  — send sites.
- `backend/.env` (VPS, secret) / `backend/.env.example` (repo) — mail config.
- Related: `docs/BRIEF-dns-and-media-performance-2026-07-01.md` (do DNS once).
