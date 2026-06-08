# Needs Achia — parked decisions

Decisions and gates that need a non-engineering (product / legal / business)
call. Claude Code does **not** block on these: it parks the gated item here and
keeps working on everything else.

_Last updated: 2026-06-08._

---

## ✅ Resolved 2026-06-08 (see `DECISIONS-gates-resolved-2026-06-08.md`)

Achia's calls, being implemented by Claude Code:

- **DG1 — Silent-recording consent → BUILD a consent + disclosure flow.** One-time
  consent screen + a disclosure at the capture point; keep the patented feature.
  Build the mechanism now; **final legal wording is Achia's lawyer's**. ⚠️
  **Release blocker** for the recording feature — must be in the next App Store
  release, so the `🚀 RELEASE MILESTONE` signal is **held** until it's in and
  green on staging. _Status: implementing._
- **DG6 — Billing → REMOVE Cashier/Stripe.** _Status: implementing._
- **DG9 — Account deletion → HARD-DELETE.** Keep current behaviour; remove the
  unused `deleted_at` column + any `whereNull('deleted_at')` filters; do NOT add
  SoftDeletes. _Status: implementing._
- **DG7 — v2 chat is the KEEPER.** Do the 4f/EP6 API work on v2. **Do NOT retire
  v1 yet** (live app may still use it; retire after the new app is live). _Status:
  guides 4f; no v1 deletion._
- **DG5 — Language → real localization.** Add `flutter_localizations` + ARB +
  English baseline; fix the `Accept-Language` mismatch. Don't hardcode a 2nd
  language yet. _Status: queued._
- **DG4 — Theme → DARK-ONLY for now.** Structure colour tokens for one dark
  theme; defer light mode. _Status: queued._
- **DG3 — Committed Firebase config → ACCEPT + DOCUMENT.** Leave committed +
  document. **Achia restricts the keys by app/bundle id in Google Cloud.**
  _Status: queued._
- **DG2 — Social login → DELETE.** ⚠️ **Needs re-confirm — see below.**

### ⚠️ DG2 re-confirmation needed (premise changed)

The decision says *"delete the **dead** social-login code (unrouted method +
non-existent column writes)."* But an audit found social login was **since wired
up and is working + tested** (route `social/signin/{provider}` → working
`socialSignin`; `SocialAuthService::googleAuthenticate` writes valid columns;
`SocialLoginTest` green). So it is **no longer dead code** — deleting it now would
remove a **working, tested feature**.

**Question for Achia:** is the intent (a) *remove social login as a product*
(delete the now-working feature), or (b) the decision was based on the old dead
state and, since it works, **keep it**? Claude Code is **not** deleting working
code on a stale "it's dead" premise without this confirmation.

---

## Still pending (not resolved)

### DG8 — original `composer.json` from the dev team
- Achia will request it from the original dev/agency. Until it arrives, CI stays
  on `composer update`. **No Claude Code action yet.**

---

## BLOCKER — production deploy (operator's lane)

The production *backend* deploy is **frozen** until the new iOS app is released
to the App Store and adopted (app-first — deploying the new backend to the old
live app broke it once). Merging `develop`→`main` is fine (code only); the
production Backend Deploy gate stays **unapproved** until the app is live.
Separately, the GitHub-runner → server SSH was rate-blocked by Hostinger's
abuse-protection; do **not** run any CI→prod connection (it re-extends the
block). Operator + Achia own this.

---

## On hold (do not act unless Achia re-confirms)

- **Roll `develop` back to the old version** — floated, on hold; do not act.
