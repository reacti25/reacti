# Needs Achia — parked decisions

Decisions and gates that need a non-engineering (product / legal / business)
call. Claude Code does **not** block on these: it parks the gated item here and
keeps working on everything else.

_Last updated: 2026-06-19._

---

## Staging email — RESOLVED (2026-06-19): dedicated isolated test-mail

**Decision (Achia):** staging sends OTP/verification emails through a **dedicated
free test-mail account** (Mailtrap Email Testing) — **never** the production mail
credentials. Production `.env` is untouched; staging stays isolated from prod's
mailbox, sending quota, and sender reputation.

**Why it was needed:** staging never delivered the registration / password-reset
OTP emails (its `.env` mail was log/blank), so the signup flow couldn't be
verified on staging before a `develop`→`main` promotion.

**Wired:** `staging-deploy.yml` now injects `MAIL_*` into the staging `.env` from
`STAGING_MAIL_*` GitHub secrets (PR #203), mirroring the analytics-env sync,
guarded to a no-op until the secrets exist. The 8 `STAGING_MAIL_*` secrets are
set (Mailtrap creds). **Pending:** one successful staging deploy to apply them —
the 2026-06-19 00:30 deploy timed out at the rsync step (transient staging-VPS
connectivity; it had deployed fine at 22:00). Retry the staging deploy when the
VPS edge is reachable; do not hammer (re-extends any Hostinger block).

---

## Testing/CI/Safety plan gates (`docs/PLAN-testing-cicd-safety-2026-06-12.md`)

### B2 (operator) — activate the staging smoke by setting the SMOKE_* secrets
The post-deploy smoke now chains off **Staging Deploy** (develop), but it
**skips** the login-dependent steps until the `SMOKE_*` GitHub secrets are set
(the health check still runs, so the workflow is green-but-partial meanwhile).
To turn on full staging validation (incl. the patent send → mark-viewed loop),
the **operator** sets, as GitHub Actions secrets, the **staging seed accounts**:
`SMOKE_USER_A_EMAIL=smoke-a@reacti.test`, `SMOKE_USER_B_EMAIL=smoke-b@reacti.test`,
`SMOKE_USER_A_PASSWORD` / `SMOKE_USER_B_PASSWORD` = `STAGING_SEED_PASSWORD`, and
`SMOKE_GROUP_ID` = the staging "Smoke Test Group" id. No prod server access
needed — these point at `staging.reacti.io`. (Never paste these into chat.)

### B1 (deferred) — iOS integration tests, gated on the same staging login secret
**Decision (Achia, 2026-06-13): DEFER B1** until the operator sets the staging
seed-account login secret above. B1 drives the real app against staging and so
**can't authenticate without it**; the patent loop is already covered from
several angles (the Flutter patent harness, the staging smoke once creds land,
and Achia's on-device TestFlight check), and it's the costliest item (macOS
runners ~10×). No point burning minutes on a self-skipping shell — build it when
the secret lands.

**When built (later), go LEAN:** `app/integration_test/` on `macos-15`, pointed
at staging via `--dart-define`, triggers `pull_request:[main]` + `push:[develop]`
only, runtime < 10 min, non-required at first. Cover: login (`smoke-a`) → chat
list → open private chat → send → receive; group send/receive. Assert the patent
**trigger** only (`mark-viewed` + reaction-send fire) — **no real camera /
no camera-fake** (the simulator has no camera, and the full patent UI is already
covered by the existing Flutter harness; the extra flake/runtime isn't worth it).

### ✅ A1 answered (2026-06-12) — tag pinned
Achia: live App Store app = **v1.0.9 (build 10)**, = imported production source
at commit **d064643** (version not bumped since). Tag **`app-live-v1.0.9`**
created on d064643 and pushed (NOT the later `develop-pre-reset-2026-05-30`).

> ⚠️ **Audit finding that needs an Achia/operator call:** the current `develop`
> backend is **genuinely NOT backwards-compatible** with the live v1.0.9 app.
> The live app parses `is_viewed` as an **int** (`int? isViewed`), but develop's
> `Chat` model casts `is_viewed` to **bool**, so the conversation/inbox response
> would **crash** the live app at parse time — the exact 2026-05-23 mechanism.
> This is *why* the prod backend deploy is frozen (app-first). Consequence: once
> the A1 backwards-compat test is wired to actually run, it will be **RED against
> develop by design** until the new app (which handles the new shape) is the live
> one and the tag is re-pinned.
>
> **DECISION (Achia, 2026-06-12): HOLD activation until the new app ships.**
> The scaffold stays a safe no-op for now. When the new app is live: (1) re-pin
> `app-live-vX.Y.Z` to the **new** shipped commit, (2) implement the real
> assertion step in `backwards-compat.yml`, (3) turn it on — at which point it
> should be **green** (the new live app handles the current response shapes) and
> will then guard against *future* breaks. Until then, do NOT wire it to run.

### ✅ A2 answered (2026-06-12) — config extracted, follow-ups parked
Achia: `climbiq-goonclimbers.com:8081` is **not** leftover — it's the real
self-hosted websocket endpoint the live app uses. So A2's config extraction
**keeps the current values as production defaults** (done: realtime
host/port/key/auth-URL now read from `--dart-define`, defaulting to the live
values, so messaging is unchanged). **Still parked (app-first, do later):**
- **Operator:** set `PUSHER_*` / `BROADCAST_AUTH_URL` GitHub secrets to the
  values Achia confirms from the prod `backend/.env`
  (`BROADCAST_CONNECTION` + `PUSHER_*`/`REVERB_*`), then wire guarded
  `--dart-define`s into `ios-testflight.yml` (staging) / `ios-release.yml` (prod).
- **Rotate** the committed app key **after the new app ships** (rotating before
  the old live app updates would break realtime on the live app).
- **Migrate** the realtime host to a `reacti.io` domain — separate, later, app-first.

---

## ✅ Resolved 2026-06-08 (see `DECISIONS-gates-resolved-2026-06-08.md`)

Achia's calls, being implemented by Claude Code:

- **DG1 — Silent-recording consent → BUILD a consent + disclosure flow.**
  **Behaviour (Achia, 2026-06-08):** consent is shown **once at registration**.
  If the user declines — or later revokes OS camera permission — they **cannot
  use the reaction feature** (private or group). When they tap to open new media
  without consent/permission, a **pop-up** explains they must consent and offers
  to **grant consent + permission inline**, or **cancel** (and not view it). Keep
  the patented feature for those who accept. **Final legal wording is Achia's
  lawyer's.** ⚠️ **Release blocker** — must be in the next App Store release, so
  the `🚀 RELEASE MILESTONE` signal is **held** until it's in and green on
  staging. _Status: implementing the capture-point consent gate first._

  **↳ DEFERRED AGAIN for 1.4.0 (Achia, 2026-07-20).** The F1–F5 implementation
  was reverted off `develop` (`7c49910`) before the first release and is **not
  in the code today** — `recordVideoSilently()` has no consent gate; a user who
  denies camera permission simply sees the media with no reaction sent, no
  disclosure and no cancel option. Achia was shown this and chose to **ship
  1.4.0 without consent**, on the basis that *"the app is still in development
  and I give only friends [to] use it"* — i.e. a closed, known, friends-only
  tester group rather than the public.

  ⚠️ **This deferral is scoped to closed testing and does NOT carry to a public
  launch.** Before the app is opened to users outside Achia's personal circle —
  or promoted/marketed publicly — DG1 must be revisited. Still blocked on two
  things: (1) the lawyer's final copy (placeholders
  `[[CONSENT_COPY_PENDING_LAWYER]]` must never ship), and (2)
  `docs/BRIEF-recording-consent-at-signup-2026-07-01.md`, which reopens whether
  consent folds into the existing Terms acceptance or is a separate step and is
  marked as needing counsel's opinion — so re-applying `feature/dg1-consent`
  verbatim may be the wrong shape. Prior work preserved on `feature/dg1-consent`.
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

### Staging realtime (Pusher) is OFF — group/1:1 messages don't arrive live
- **Found 2026-06-21** while investigating "group messages don't appear / others
  don't receive them" on staging. The staging `laravel.log` shows every send
  using the **`log` broadcaster** (`Broadcasting [GroupMessageSendEvent] on
  channels [...] with payload:`), i.e. broadcasts are written to the log and
  **never sent to Pusher**. So there is no realtime delivery on staging for anyone.
- **Cause:** `staging-deploy.yml` syncs analytics + mail env into the staging
  `.env`, but **not** Pusher/broadcast. So staging has no `PUSHER_*` and
  `BROADCAST_CONNECTION` is effectively `log`.
- **Needs Achia/operator:** provide the staging Pusher app creds as GitHub
  secrets (`PUSHER_APP_ID`, `PUSHER_APP_KEY`, `PUSHER_APP_SECRET`,
  `PUSHER_APP_CLUSTER`). Once they exist I'll add a guarded env-sync step to
  `staging-deploy.yml` (same pattern as the analytics/mail sync) that sets
  `BROADCAST_CONNECTION=pusher` + the `PUSHER_*` keys, and confirm the app's
  staging Pusher key/cluster match. **No further Claude action until the
  secrets are provided.**
- Separately: every send logs `SplFileObject(...STAGING-PUSH-DISABLED.json):
  No such file or directory` — the Firebase push path choking on a missing key
  file. Non-fatal (sends still succeed) but noisy; worth a small follow-up to
  guard the push service when push is disabled on staging.

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
