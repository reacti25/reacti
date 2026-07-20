# Progress — app-hardening master plan

Status board for `docs/MASTER-PLAN-app-hardening-2026-06-04.md`, kept current
by Claude Code so Achia and the operator can see at a glance what has landed on
`develop`, what is next, and where a `develop`→`main` promotion makes sense.

**Convention:** every line item is a small PR off `develop`. ✅ = merged to
`develop`. 🔄 = in progress / PR open. ⬜ = not started. ⛔ = parked on a
decision gate (see `NEEDS-ACHIA.md`).

_Last updated: 2026-07-20._

---

## 🚀 RELEASE MILESTONE — media, notifications & message actions (2026-07-20)

The largest batch since launch: **66 commits** on `develop` since `main`,
shipping as **1.4.0+17**. **App first, then backend** — the prod Backend Deploy
gate stays **UNAPPROVED** until the new app is live and adopting.

> ⚠️ **This release raises the iOS minimum from 13.0 to 16.0** (required by the
> media rebuild). iPhone 7 and older can never run it. Achia accepted this
> 2026-07-20 on the basis that her user base is well above that floor.

### Next release — what's in it (plain language)

**Sending photos & videos feels like WhatsApp now:**
- **Pick several photos at once**, add one caption, send them as a batch.
- The picker opens as a **sheet over the chat** and **drags up to full screen**.
- A **built-in photo editor** (the pencil) before you send.
- Sent media **appears instantly** instead of after the upload finishes — the
  "why is this so slow" delay is gone, especially on a weak connection.
- **Flash toggle** in the camera, and the camera **re-opens after you discard**
  a shot instead of dumping you back to the chat.

**One-time media (view-once):**
- Send a photo or video that **disappears after it's opened once**, in both 1:1
  chats and groups.

**Notifications actually work:**
- Push notifications now **make a sound** (iPhone was completely silent before).
- **Tapping a notification opens the right chat** instead of just the app.
- The **app icon shows a badge** with the number of chats waiting.
- Sounds are now **one per message**: outside the app you hear the notification
  tone, inside the app you hear the in-app tone — never both.
- A rotated push token now **re-registers itself**, so notifications can't
  silently stop working until you log in again.

**Message actions (long-press a message):**
- **Edit** a sent message within 10 minutes (the option disappears after).
- **Forward** a message to several chats and groups at once.
- **Delete for me**, and see the **exact time** a message was seen.

**Smaller things:**
- Tap a **profile photo or a chat-header photo to enlarge** it.
- **Find friends by username**, with the request button guarded against
  double-sending.
- **Haptic feedback** on send and receive, with a Sound & Vibration setting.
- Long 1:1 chats **load older messages as you scroll**, so they open faster.
- Privacy note on the contacts prompt; you can **revisit the intro** from login.

### Ship sequence
1. Bump to **1.4.0+17** (this PR), merge to `develop`, promote `develop`→`main`.
2. Tag **v1.4.0** on `main`; run the production iOS release workflow; Achia
   submits the build for App Store review.
3. After the new app is **live and adopting**, the operator approves the
   **production Backend Deploy** gate — this is what finally gives the push
   notification sound to real users.

---

## 🚀 RELEASE MILESTONE — video freeze fixed + speed (2026-07-08)

A user-meaningful batch verified on the Reacti Staging build (Achia confirmed
on-device, builds 1102–1109) and ready to ship as **1.3.2+16**. **App first,
then backend** (same rule always: the live App Store app is the OLD app; the
prod Backend Deploy gate stays **UNAPPROVED** until the new app is live). The
only backend change is additive (the group Unseen count reads existing
per-message state), so the currently-live app keeps working.

### Next release — what's in it (plain language)

**The big fix — videos:**
- Videos used to freeze / black out (all at once, after ~a minute of watching
  several). **Fixed at the root** — a listener leak on the shared video players
  that starved iOS's video decoding — and **locked with a regression test** so
  it can't come back.

**Faster:**
- Photos and videos are **compressed before sending** → upload faster, load
  faster, videos play smoother.
- **Faster app start** (independent startup steps run in parallel).
- **Smoother video playback** (less CPU/battery).
- **1:1 chats load older messages on scroll** so long conversations open quicker.
- **Media served through a global edge cache** (Cloudflare, infra — already live
  for everyone, ~8× faster first-load for distant users).

**Fixed / improved:**
- **Front camera** no longer sticks when switching in the in-app camera.
- **Group "Unseen"** now stays set while media is unopened (matches 1:1).
- **Groups with no photo** show a friendly people icon (chat list, inside the
  group, group details) + group details fixed in light mode.

### Ship sequence
1. Bump to **1.3.2+16** (this PR), merge to `develop`, promote `develop`→`main`.
2. Tag **v1.3.2** on `main`; run the production iOS release workflow; Achia
   submits the build for App Store review.
3. After the new app is **live and adopting**, the operator approves the
   **production Backend Deploy** gate.

## 🚀 RELEASE MILESTONE — media speed & reaction authenticity (2026-06-25)

`docs/PLAN-media-timing-and-speed-2026-06-23.md` hit its North-Star on the
Reacti Staging build and Achia verified it on-device. A user-meaningful batch —
**ship it, app first, then backend** (same rule as every release: the live App
Store app is the OLD app; the prod Backend Deploy gate stays **UNAPPROVED**
until the new app is live). Backwards-compat + Contract suites green, so the
backend changes are old-app-safe.

### Next release — what's in it (plain language)

**Media feels instant:**
- Received photos/videos now open **immediately** — previously you often had to
  leave the chat and come back to see them. Media is also **pre-loaded on
  arrival**, so opening it is near-instant (load time p90 fell from ~1.2s to
  well under it; cache-hits are effectively 0ms). Images decode at screen size
  instead of full resolution (less lag/memory).
- A **received video plays on the single tap** that opens it (was two taps).

**The silent reaction is now authentic:**
- The reaction recording now starts when the media is **actually on screen**
  (first painted frame) instead of while it's still loading — so the captured
  reaction overlaps the real media (**~100%** vs. partial before). *Ships behind
  an off-by-default flag; activates in prod once prod analytics/flags are set
  up — see caveat below.*

**Bug fixes (chat):**
- A sent photo/message no longer **vanishes after sending** (1:1 and group).
- **Group reactions** no longer arrive **sealed** — they show directly, like 1:1.

**Under the hood:**
- Full tap→painted→record timeline instrumentation + a feature-flag kill-switch
  (both observation/safety only). Staging realtime fixed so staging finally
  mirrors prod (received messages arrive live).

**⚠️ Caveat — the reaction-overlap win ships inert in prod:** it's behind the
`reaction_trigger_on_paint` flag, which is **off** in production until prod
PostHog/analytics + a prod flag exist (the paused analytics Phase 1). Everything
else activates the moment the app installs.

**Deliberately NOT in this batch (YAGNI — targets already beaten):** thumbhash
placeholder (2.1), WebP variants (2.5), MP4 faststart (2.6). Revisit only if
real-world prod data shows a need. Still open: reaction upload-retry (2.4 —
reliability, coordinate with the reaction-reliability plan).

---

## 🚀 RELEASE MILESTONE — ready to ship (app first, then backend)

**Reached 2026-06-08.** The named milestone (Stage 4c complete) plus the
security and patent-flow hardening is **done, on `main`, and verified by Achia on
the Reacti Staging TestFlight build.** This is a user-meaningful batch (safer
*and* visibly better), so per the operator cadence it's a release point.

**⚠️ Order matters — APP FIRST, then backend.** The live App Store app is the
OLD app; deploying the new backend first changed response formats the old app
can't read and **broke the live app once** (rolled back). So:
1. **Release the new iOS app to the App Store** (Achia drives) and let it adopt.
2. **Then** the operator approves the production Backend Deploy gate.

The production Backend Deploy gate stays **UNAPPROVED** until the app is live.

### Next release — what's in it (plain language)

Everything below is in the new app/backend vs. the OLD App Store version:

**Security (the big one):**
- Removed publicly-reachable maintenance URLs that could **wipe the database**.
- Login/OTP screens are now **rate-limited** (the 4-digit code was
  brute-forceable in seconds).
- OTP codes are **no longer returned in API responses** (was a trivial
  account-takeover path).
- Removed an app-wide setting that **disabled HTTPS certificate checking**
  (every request was interceptable).
- The login token is now stored **encrypted** and is **fully erased on logout**.
- Locked down CORS, secured upload-folder permissions, hardened the admin
  settings routes, and made session cookies **HTTPS-only**.

**Visibly better:**
- A failed load now shows **"Couldn't load… / Retry"** instead of a **blank
  screen** (chat list, conversation, group).
- Picking a photo/video now shows it **inside the message box** with a **lit-up
  send button**, so it's clear it hasn't been sent until you tap send (fixes the
  old behaviour where the preview floated above and looked already sent).

**Patent flow (the silent reaction recording):**
- Hardened internally (de-duplicated the code, guards against a crash on
  malformed messages, failure logging) — **behaves the same**, just safer.
  *(The consent/permission UX is a separate legal decision — DG1.)*

**Under the hood (not user-visible, but protects all of the above):**
- A full automated test safety net incl. the patent-flow end-to-end harness, an
  enforced coverage floor, and the CI gates.

### Building toward the *next* release (after the one above ships)

Accumulating on `develop` since the milestone — will go in the release *after*
the pending App-Store release:
- ⚡ **Faster failures:** a dead server / no-internet now fails in **~30s**
  instead of leaving you on a **10-minute** spinner (Dio connect timeout, #141).
- ⚡ **Faster app open:** removed a hardcoded **3-second** splash delay on every
  cold start (#142).
- 🧱 Internal: `users` indexes (#139) and model-drift cleanup (#140).

---

## 🚀 RELEASE MILESTONE — Phase A (testing / CI / safety) complete (2026-06-12)

Phase A of `docs/PLAN-testing-cicd-safety-2026-06-12.md` is **done and merged to
`develop`** (PRs #149–#154 + annotated tag `app-live-v1.0.9`), green on the
required checks (**"PHP Tests"**, **"Analyze & Test"**). It is a **safety /
security** batch that directly hardens the live app's protection:

- **API + realtime shape locks (A4, PRs #149/#153/#154):** contract tests now pin
  the exact wire shapes of the chat / group / auth / friends endpoints **and** the
  Pusher broadcast payloads — including the patent `reaction` path and the
  **group-int vs. 1:1-bool** `is_viewed` divergence that caused the 2026-05-23
  outage. A future shape break now fails CI before it can reach the App Store app.
- **Security (A3, #150):** `.env.example` is production-safe — no more
  `APP_DEBUG=true` Ignition stack-trace leak; `docs/configuration.md` added.
- **A2 (#152):** realtime host / key / auth-URL moved out of inline client code
  into build-time config — **no behaviour change** (current values kept as
  defaults).
- **A1 (#151):** the backwards-compat safety net is scaffolded and the live-app
  tag pinned (`app-live-v1.0.9` @ `d064643`); activation is **held until the new
  app ships** (the audit found develop's backend is not backwards-compatible with
  the live v1.0.9 app on `is_viewed` — bool vs the app's int).

**Release-worthy — but mind the gates (nothing here triggers a release):**
- **App-first.** Achia drives the App Store release; the operator deploys the
  backend **after** the new app is live. The prod Backend Deploy gate stays
  **UNAPPROVED**.
- ⛔ **DG1 (consent flow) still gates the actual release** (see `NEEDS-ACHIA.md`).
  This Phase A work **rides** the next release; it does not justify one on its own.
- ⚠️ **Staging health is not auto-validated.** Staging *deploys* succeed on every
  develop push, but the post-deploy smoke chains off the prod **"Backend Deploy"**
  on `main`, not staging-deploy — so the patent loop isn't auto-checked on
  staging. Automating that is **B2** (Phase B). Until then, on-device confirmation
  on the Reacti Staging TestFlight build is Achia's; A2 touched app code (realtime
  config), so a **fresh staging TestFlight build** is warranted even though
  behaviour is unchanged.

**Next:** Phase B (test-wall completion + app-side input hardening) is ready when
Achia gives the go-ahead — **not started** (no new phase without approval).

---

## Testing / CI / Safety plan (`docs/PLAN-testing-cicd-safety-2026-06-12.md`)

Now the active driver for repo work. Phases A→D; one small PR per task off
`develop`, kept green on **"PHP Tests"** + **"Analyze & Test"**.

### Phase A — protect live users

- ✅ **A4 PR1 — group + patent contract tests** (#149): group list/messages/send,
  group + 1:1 patent `reaction`, group `mark-viewed`; locks the real **group int
  vs. 1:1 bool** `is_blurred`/`is_viewed` divergence.
- ✅ **A4 PR2 — auth/friends contract tests** (#153): `POST /register`,
  `GET /user-profile/{id}`, `GET /friends/list`, `POST /friends/send-request`.
  _Audit aside: `AuthService::register` reads `$data['last_name']` unguarded, so
  registering without the optional last_name 500s — a latent backend bug, left
  out of scope here (tests-only); worth a Phase-B/backlog fix._
- ✅ **A4 PR3 — broadcast event payload contracts** (#154): pins
  `MessageSendEvent` / `GroupMessageSendEvent` / `MessageReactionEvent` payloads
  (the realtime wire surface), completing A4's scope.
- ✅ **A3 — prod-safe `.env.example` + `docs/configuration.md`** (#150): defaults
  `APP_ENV=production` / `APP_DEBUG=false` / `LOG_LEVEL=error` (no Ignition leak),
  config doc + `EnvExampleProdSafeTest`.
- ✅ **A2 — realtime config out of client code** (#152): host/port/key/auth-URL
  read from `--dart-define` (`RealtimeConfig`), defaulting to the current
  production values so live messaging is unchanged. Secret/workflow wiring + key
  rotation + `reacti.io` migration parked app-first in `NEEDS-ACHIA.md`.
- 🔄 **A1 — backwards-compat workflow scaffold** (#151): a no-op until the
  live-app tag is pinned. Tag `app-live-v1.0.9` @ `d064643` pinned; **activation
  held until the new app ships** (Achia, 2026-06-12) — audit found develop's
  backend is not backwards-compatible with v1.0.9 (`is_viewed` bool vs the live
  app's int → would crash it). See `NEEDS-ACHIA.md`.

**Audit note (for Phase B):** B3's premise is already partly satisfied —
`routes/api.php` already constrains `social/signin/{provider}` to
`['google','apple']`. B3 narrows to adding the 422-rejection test.

### Phase B — close the test-wall gaps & app-side safety

Order (Achia, 2026-06-12): **B2 → register fix → B4**, then stop & check in
before **B1** (macOS-runner cost); **B3 held** pending **DG2** (keep/remove
social login — don't harden code that may be deleted).

- ✅ **B2 — post-deploy smoke chains off staging-deploy** (#156): now triggers on
  **Staging Deploy** (develop) → staging URL (was wired only to prod "Backend
  Deploy"/main, so it never validated staging). **Confirmed firing** (green
  `workflow_run` run). Self-gating: skips login steps until the operator sets
  `SMOKE_*` to the staging seed accounts (parked in `NEEDS-ACHIA.md`); health
  check still runs. Added `docs/release-runbook.md` (a red smoke blocks a
  promotion recommendation).
- ✅ **Register `last_name` fix** (#157): `AuthService::register` now null-guards
  the optional `last_name` (was a 500 on omit); `RegistrationTest` regression added.
- ✅ **B4 — scope IDOR-adjacent `exists:` rules** (#158): chat `reply_to_id` scoped
  to the conversation, group `reply_to_message_id` scoped to the `group_id`,
  `findContacts` raw `{$user->id}` → bound param + `contacts` `max:1000`.
  _Audit: `forwardMessage` does not exist in the codebase — dropped from B4 (the
  plan was stale on it)._
- ⛔ **B3 — social-provider whitelist** — held pending **DG2** (the route is
  already constrained to `['google','apple']`; B3 = the 422-rejection test).
- ⛔ **B1 — iOS integration tests in CI** — **deferred** (Achia, 2026-06-13):
  gated on the same staging login secret as B2, costliest item, patent loop
  already covered. Lean spec recorded in `NEEDS-ACHIA.md` for when the secret lands.

**Phase B actionable items are complete** (B2 + register fix + B4 merged); B1
deferred and B3 held, both parked in `NEEDS-ACHIA.md`. Like Phase A, this batch
(IDOR scoping + a crash fix + staging-smoke validation) is security-meaningful
and **rides the next DG1-gated release** — it does not trigger one.

---

## Stage 0 — CI gates + test machinery (EP0)

Largely completed by earlier work (PRs up to #119 + dependabot/dashboard
commits). Verified present on `develop`:

- ✅ Both required checks always report (no `paths:` filter on `backend-ci.yml`
  / `flutter-ci.yml`).
- ✅ PHPStan/Larastan with baseline (`backend/phpstan.neon` +
  `phpstan-baseline.neon`); gate fails only on *new* violations.
- ✅ `dart format --set-exit-if-changed` + `flutter analyze` gates.
- ✅ Native build jobs: Android debug + iOS no-codesign (non-required, observed).
- ✅ Coverage reporting on both pipelines (no floor yet — floor comes in Stage 1).
- ✅ `composer audit` job (non-required; surfaces deferred CVE-2026-48019).
- ✅ Dependabot (`.github/dependabot.yml`: composer / npm / pub / actions).
- ✅ `deploy-dashboard.yml` points at `develop`.
- 🔄 Mop-up: fold the non-fatal `|| true` ssh-keyscan fix into
  `prod-deploy-check.yml` + `staging-deploy.yml` (match `backend-deploy.yml`).
- ⛔ Switch CI `composer update`→`composer install` — blocked on **DG8**
  (need the original `composer.json`). See `NEEDS-ACHIA.md`.

## Stage 4a — security criticals, exploitable today (EP1) — pulled forward

Highest real-world risk; done right after the Stage 0 mop-up. An audit found
items 1–4 were already fixed and tested on `develop` by earlier work; this
initiative closed the remaining token item.

- ✅ Delete the unauthenticated `routes/web.php` maintenance routes
  (`/run-migrate-fresh` can drop the DB). *(already on `develop`; pinned by
  `MaintenanceRoutesRemovedTest`.)*
- ✅ Rate-limit auth/OTP routes (`throttle:` on login/register/OTP). *(already on
  `develop`; pinned by `AuthRateLimitTest`.)*
- ✅ Stop returning OTP codes in API response bodies. *(already on `develop`;
  pinned by `OtpNotInResponseTest`.)*
- ✅ Remove the `MyHttpOverrides` TLS bypass in `app/lib/main.dart`. *(already on
  `develop`; pinned by `no_tls_override_test`.)*
- ✅ Erase the session on logout — `totalDataClean()` on the **success** path
  (was only on the 401 path). PR #124.
- ✅ Move the auth token to `flutter_secure_storage` (`AuthTokenStore`,
  secure-at-rest + synchronous in-memory mirror). PR #125.

### ✅ CHECKPOINT — Stage 4a complete (ready for Achia)

Stage 4a (EP1 exploitable-now security criticals) is **complete and green on
`develop`/staging.** Per the handoff cadence, work is **paused here** for your
test + promotion before the next big step (Stage 1 — the patent-flow harness).

**What changed (security):** logout now fully clears the session; the auth
bearer token is stored encrypted in the platform secure store (Keychain /
Keystore) instead of the plaintext GetStorage file. The other 4a criticals
(maintenance routes, OTP rate-limiting, OTP-not-in-response, TLS-bypass removal)
were already on `develop` and are each pinned by a regression test.

**This step changed Flutter/app code** (logout, token storage, Dio header, chat
init, login/signup) — so you need a **fresh staging TestFlight build** to test it
on your iPhone. Backend was unchanged by the app-side PRs.

**What to test on the Staging app (TestFlight):**
1. Log in → use the app (chat list, open a conversation) → confirm everything
   still works (the token now comes from secure storage).
2. Log out → confirm you land on the login screen and a subsequent app action
   requires logging in again (no lingering session).
3. Log in again → kill and reopen the app → confirm you stay logged in (the
   token persists across restarts from secure storage).
4. Sign up a new account through OTP verification → confirm you end up logged in.

**Then:** if it looks good, this is a natural point to promote `develop`→`main`.
Tell me to continue and I'll start Stage 1 (the patent-flow integration
harness). The remaining 4b–4k hardening and Stage 1 are **not** started.

## Stage 1 — test net / patent-flow harness

- ✅ Patent-flow integration harness — full-loop **InboxScreen** (PR #127) and
  **GroupInboxScreen** (PR #128) tests (tap → mark-viewed → record → upload as a
  reaction → unblur; group also pins the optimistic insert). Added a reusable
  realtime-injection seam + fake `video_player` platform, and fixed a GetStorage
  test file-lock race. **This unblocks safely touching the patent code in 4d.**
- ✅ Risky paths broadly covered — an audit confirmed the net was already strong:
  **~100% of the app `rx_*` data-source layer** is unit-tested and **nearly every
  backend endpoint** has feature coverage. (Service-level *unit* tests with true
  DI are deferred to EP7; a few read endpoints — chat `room`, group
  `available-users`/`messages/media` — remain thinly covered, noted for
  opportunistic follow-up.)
- ✅ Coverage floor enforced (PR #129): backend `--min=70` (≈78% now), app ≥35%
  line (≈37.5% now) — low by design, to ratchet up.

### ✅ CHECKPOINT — Stage 1 complete (no staging action needed)

Stage 1 is **complete and green on `develop`.** Per the cadence, work is **paused
here** before Stage 2.

**Nothing to test on staging / no new TestFlight build needed.** Stage 1 is a
*tests + CI* stage — it added the safety net, not behaviour. The only production
change was a behaviour-preserving seam (how a chat screen obtains its realtime
connection; default unchanged), so the app behaves exactly like the build you
already tested after 4a, and `backend/` was untouched.

**Promotion is optional here** (no behaviour change to ship), but `develop` can be
batched into the next `develop`→`main` promotion whenever convenient. The next
stage that produces something *visible to test on staging* is the behaviour-
changing hardening (Stage 4b/4c). Awaiting your go-ahead to start **Stage 2**
(documentation — also invisible) or to skip ahead.

## Stage 2 — documentation

- ⬜ Dartdoc / PHPDoc everywhere; `docs/architecture.md`; API spec;
  README/LICENSE/CONTRIBUTING.

## Stage 3 — safe refactor leftovers (mostly done already)

- ⬜ `achiar_expert_app`→`reacti` rename; safe dead-code deletion; prune deps.

## Stage 4c — correctness bugs (EP3) ✅

Done out of plan order (Achia's call, to get something testable on staging). An
audit found **5 of the 6 EP3 bugs already fixed** on `develop` (typing-event 500
route removed, `dd("jalis")` gone, profile→`first_name`, dead admin-group routes
removed, social login wired). The one genuine remaining bug was fixed:

- ✅ Error + retry instead of a blank screen on a failed load — chat list /
  inbox / group inbox (PR #130). **App-visible; verified by Achia on a staging
  TestFlight build.** Promoted to `main` in PR #131.

## Stage 4b — security hardening (EP2) ✅

Audit found most EP2 items already done (exception leaks, OTP CSPRNG, channels
PII logging, app log redaction, `FirebaseTokens $fillable`, test-s3 route). The
genuinely-open items, each fixed test-first:

- ✅ CORS restricted from wildcard `['*']` to the known web origins, env-driven
  (PR #132).
- ✅ Upload dir created `0755`, not world-writable `0777` (PR #133).
- ✅ Admin settings routes declare `auth+admin` explicitly (defense-in-depth;
  they were already protected by the bootstrap closure) (PR #134).
- ✅ Session cookies default to `Secure` outside local dev (PR #135).

### ✅ CHECKPOINT — Stage 4b complete (no new staging build needed)

Stage 4b is **complete and green on `develop`.** Per the cadence, work is
**paused here**.

**Nothing new to *see* on the app.** Stage 4b is **backend security hardening**
(CORS, file perms, route guards, cookie flags) — verified by tests, not
user-visible. So **no new TestFlight build is needed.** The changes auto-deploy
to the staging *server* on merge (already done).

**Promotion:** `develop` now holds Stage 4b on top of the already-promoted 4c.
It's a good batch point to promote `develop`→`main` when convenient (no
behaviour a user would notice). The actual **production** deploy remains blocked
on the GitHub-runner rate-block (operator's lane — see `NEEDS-ACHIA.md`).

**Open items deliberately deferred:** the `/api/check` unauth endpoint (used by
smoke tests — left intentionally) and trimming `User::$fillable` (needs care —
the registration/reset services assign those columns) are noted for a later,
careful pass.

## Stage 4d — patent-flow hardening (EP4) ✅ (engineering items)

Unblocked by the green Stage 1 harness; the **full patent suite was re-run on
every PR** and stayed green.

- ✅ Collapsed the duplicated `_buildBlurPlaceholder` into one path (was two
  ~70-line copies with dead inner branches) + guarded the force-unwrapped ids
  (`messageId!`/`userId!`/`groupId!`) so a null id is a safe no-op instead of an
  uncaught crash (PR #136). Behaviour-preserving on the happy path.
- ✅ Made the two failure paths observable instead of silent no-ops —
  mark-viewed-failed (retryable placeholder) and null recording (PR #137).

**Deferred — gated on DG1 (legal/product):** the camera/mic permission
pre-check and the consent UX. Requesting permission surfaces the silent
capture, which *is* the consent decision — so these wait for **DG1**
(`NEEDS-ACHIA.md`). A user-facing error toast on failure is a small follow-up
(needs GetX-overlay-safe test infra).

### ✅ CHECKPOINT — Stage 4d (engineering) complete

Green on `develop`. **This changed app code on the load-bearing patent path** —
behaviour-preserving on the happy path and verified by the full patent suite,
but because the patent flow is load-bearing it's worth a **fresh staging
TestFlight build** so Achia can confirm on-device that tap-blurred-media →
silent record → reaction-sent still works end-to-end. No new *visible* feature;
this is a "still works after the refactor" check. Remaining 4d work is
**DG1-gated**.

## Stage 4e–4k — functional hardening (remaining)

See the master plan (data model, API design, backend/app architecture,
performance, UX/i18n, cleanup).

## Stage 5 — features

- ⬜ Only after the above.

---

## Promotion checkpoints (for Achia)

The master plan calls for a TestFlight check + `develop`→`main` promotion after
**4a** and again after **4c**. This file will call those out explicitly when the
work reaches them. No promotion has been requested yet under this plan.
