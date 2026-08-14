# PLAN — Wireframe "8 Beta Deliveries" — END-TO-END IMPLEMENTATION (2026-07-21)

_For Claude Code. Source: `docs/✓ App wireframes design.pdf`. This is the buildable
companion to `docs/PLAN-wireframe-deliveries-2026-07-21.md` (the HAVE/GAP/NEW triage) —
read that first for context, this for execution._

**Ground truth reminder:** file/line references below were taken from the 2026-07 plan
docs and briefs, not re-read live. **Before editing, Claude Code must re-verify each
reference against `develop`** (`git show develop:<path>` or open the file) — line numbers
drift. Where a file is named but a line isn't, grep for the quoted literal.

**✅ All decisions locked (2026-07-21):** D1 build group react-to-unlock · D2 keep 4-tab nav
(hold People-tab #8a) · D3 scripted demo now, AI coach future-only · D4 plain invite link v1
with infra ready for paid deep-link later · D5 keep the carousel, swap unrelated images for
related ones. Only remaining input: confirm the north-star activation metric.

**⏸ Feature 1 (carousel) is deferred to LAST** — it waits on Achia's 3 related images
(Appendix B). Build everything else first; do the carousel copy + images together in one PR at
the end. Everything else is ready to build now.

---

## Global conventions (apply to EVERY PR)

- **Branch off `develop`**, one concern per PR (`docs/conventions.md`). Name branches as
  given per feature below.
- **Conventional Commits** (`feat(scope): …`, `fix(scope): …`); body explains *why*.
- **Dart:** `dart format .` + `flutter analyze` must pass; `StatefulWidget` config fields
  `final`; files `lower_snake_case.dart`.
- **PHP:** `./vendor/bin/pint`; `camelCase` methods; one response envelope
  `{success, message, data, code}`; real HTTP status codes; FormRequests for validation.
- **No l10n system exists** — all copy is hardcoded string literals styled via
  `TextFontStyle.*`. Add new strings the same way.
- **Theme:** prefer `context.reacti.<token>` (the `ReactiColors` extension in
  `app/lib/theme/app_theme.dart`). Onboarding / login / find / search screens are still on
  the legacy flat `AppColors` (`app/lib/gen/colors.gen.dart`) and are dark-only — **match
  the surrounding screen's existing style**, don't mix systems in one widget.
- **GetStorage:** key constants in `app/lib/constants/app_constants.dart`; instance is
  `appData` (from `app/lib/helpers/di.dart`).
- **CI:** each PR passes `Analyze & Test` (app) and `PHP Tests` (backend, when backend
  changes). Attach a screenshot/recording to each app PR for on-device sign-off.
- **RTL:** app supports Hebrew — spot-check any new screen in RTL (Claude Code can't run
  device; flag for Achia's on-device pass).

### 🚨 Patent guardrail (READ before #2, #3, #6, #8c)

The patented core is the **silent front-camera capture** when a recipient opens sealed
media: `receiver_message_widget.dart` → `mark-viewed` → `recordVideoSilently()` →
reaction upload (~L427/L461), backend seals media (`is_blurred`), client reads via
`isMediaSealed`. **Any PR that touches `send` / `mark-viewed` / blur flags /
`recordVideoSilently` / reaction-upload MUST re-run the patent regression suites and keep
the success path byte-for-byte identical** (CLAUDE.md north-star; `enhancement-plan.md`
rule 4). Features below that come near it say so explicitly and must add/extend the
patent regression test, not weaken it.

---

# WAVE 0 — near-free gaps

## Feature 1 (part) — Onboarding carousel copy refresh  ·  `feat/onboarding-copy-refresh`  ·  S

**⏸ DEFERRED TO LAST (Achia, 2026-07-21).** Do this feature **after everything else** — it
depends on Achia's 3 related carousel images (Appendix B), which she'll create at the end so
they're good. Don't build a placeholder version now; keep the carousel as-is until the images
are ready, then do copy + images together in one PR. (Feature 7's profile replay works against
the current carousel meanwhile and inherits the improvement automatically.)

**Goal:** bring the existing 3-slide carousel copy in line with the wireframe + swap in the
related images. No mechanic change.

**Current state:** `app/lib/features/onboard/presentation/on_board_screen.dart` — 3-slide
`PageView` + `smooth_page_indicator`, Skip + Next/Get Started. Live slide titles: "Share
Authentic Moments" / "Your Privacy Matters" / "Reaction to View". First-run routing:
`app/lib/loading.dart` reads `kKeyIsFirstTime` → `OnBoardScreen` → sets it false → login.

**Change:**
1. Rewrite the three slides' title + subtitle to the wireframe copy:
   - Slide 1 — **"Send the moment"** / "Share a photo or video with someone you care about."
   - Slide 2 — **"Catch the real reaction"** / "When they tap to open it, Reacti captures
     their genuine first reaction."
   - Slide 3 — **"No retakes. Just real."** / "Their reaction is sent back automatically
     and appears beneath the original."
2. **Keep the carousel — swap its unrelated images for related ones (D5).** The carousel
   itself is good; the problem is only that today's slide images don't match what Reacti
   does. Replace them with **related, real Reacti imagery** — one per slide: (1) sending a
   photo/video, (2) the open-and-capture moment, (3) the real chat pair (original + reaction
   beneath, with timestamps, as slide 3 of the mockup shows). See Appendix B for the exact
   frames to capture. Keep the existing slide structure (title/subtitle/image), Skip/Next, and
   count — just swap the assets + the copy.
3. Do **not** change routing, `kKeyIsFirstTime`, Skip/Next behavior, or slide count.

**Tests:** `flutter analyze` clean; existing onboarding widget test (if any) updated for
new copy. Screenshot each slide.

**Acceptance:** carousel shows the three wireframe messages over **related, real** Reacti
imagery (no more unrelated stock art), in order; first-run + skip behavior unchanged.

---

## Feature 7 — "How Reacti works" replay on Profile  ·  `feat/profile-how-reacti-works`  ·  S

**Goal:** a Profile row that replays the onboarding carousel, so users don't dig into
Settings. Depends on the carousel being re-openable (same mechanism as quick-win QW3).

**Current state:** `app/lib/features/profile/presentation/profile_screen.dart` renders
avatar + name + Friends/Groups counts + an ACCOUNT section (Edit Profile, Notifications,
Privacy). `OnBoardScreen` is only reachable as the first-run home today.

**Change:**
1. Make `OnBoardScreen` re-openable without resetting first-run (if QW3 already landed this,
   reuse it): add `final bool fromLogin;` (default false); when true, Skip / last-slide pop
   instead of writing `kKeyIsFirstTime` / replacing to login. **Coordinate with QW3** —
   if QW3 is merged, this flag already exists; don't duplicate.
2. In `profile_screen.dart` ACCOUNT list, add a **"How Reacti works"** `ListTile` with a
   trailing "Replay ▶" affordance, placed between Edit Profile and Notifications, styled to
   match the existing rows. `onTap`:
   ```dart
   Navigator.of(context).push(
     MaterialPageRoute(builder: (_) => const OnBoardScreen(fromLogin: true)),
   );
   ```
3. **D5 — reuse the carousel (now with related images).** Since D5 keeps the carousel and
   fixes its imagery (Feature 1), this replay simply **reopens that same carousel** via
   `OnBoardScreen(fromLogin: true)` — no separate video needed. (The mockup labels it
   "video"; the improved carousel satisfies the intent. A real screen-recording video is an
   optional future upgrade — Appendix B's shots would serve it — but not required for v1.)
   Ship Feature 7 **after or with** Feature 1 so the carousel it opens is already the good one.

**Tests:** `flutter analyze` clean; widget test that tapping the row pushes `OnBoardScreen`
(nice-to-have). Screenshot.

**Acceptance:** from Profile, tap "How Reacti works" → the (image-fixed) carousel opens →
paging through or Skip returns to Profile; first-run semantics untouched.

---

## Feature 3 (the real gap) — Chat-list preview labels  ·  `feat/chat-list-preview-labels`  ·  S

**Goal:** each conversation row says what's inside instead of "File attachment": **"New
photo Reacti"**, **"New video Reacti · 0:24"** (with duration), **"Reaction received"**.

**Current state:** the conversation-list subtitle currently renders a generic
"File attachment" for media. The combined chat list is built by backend
`ChatService::listCombined` → `CombinedChatResource`; the app model is `Chat` (has
`unreadCount`, `isSeen`, `isMediaSealed`, last-message fields). **Locate the exact subtitle
widget by grepping the app for the literal `"File attachment"`** (likely an inbox/chat-list
item widget under `app/lib/features/chat/…` or an inbox feature). Confirm what fields the
last-message payload exposes (message type, media type, `is_blurred`/sealed flag, video
duration) via `CombinedChatResource`.

**Change (client-first; add backend only if a field is missing):**
1. Replace the hardcoded "File attachment" subtitle with a **label derived from the last
   message**:
   - Photo media → **"New photo Reacti"**
   - Video media → **"New video Reacti · M:SS"** (format the duration; if duration isn't in
     the payload, see step 3)
   - A received reaction message → **"Reaction received"**
   - Plain text → the text preview (unchanged)
2. Put the mapping in one helper (e.g. an extension on `Chat`/last-message, or a
   `chatPreviewLabel(...)` function) so 1:1 and group lists share it. Keep icons if the
   wireframe shows them (📷 / 🎬 / ✓).
3. **Video duration:** if `CombinedChatResource` doesn't already carry the last media's
   duration, add it **additively** (nullable `duration` seconds on the resource + the
   `Chat` model; default null → omit the "· M:SS" suffix). Backend change is a read-only
   resource field — no migration if duration is derivable from the stored message; if it
   isn't stored, fall back to no-duration label and note it.
4. Respect sealed/unseen state: a sealed-but-unopened item still shows its type label
   ("New photo Reacti"), consistent with the wireframe's "says exactly what's waiting".

**Patent note:** display-only; must not change seal/mark-viewed logic. If you only read
existing fields, no patent-path risk. If you add a resource field, it's read-only.

**Tests:**
- Client: widget test that a photo/video/reaction/text last-message renders the right
  label (+ duration formatting). Update `app/test/networks/endpoints_test.dart` only if the
  resource shape changes.
- Backend (only if a field is added): a `CombinedChatResource` test asserting the new
  nullable field is present and defaults null.

**Acceptance:** conversation rows read "New photo Reacti" / "New video Reacti · 0:24" /
"Reaction received" per the wireframe; text previews unchanged; no change to open/seal
behavior.

---

# WAVE 1 — the flagship

## Feature 2 — Private demo Reacti  ·  `feat/demo-reacti`  ·  M–L  ·  DECISION D3

**Goal:** every first-time user gets one harmless practice Reacti: "Tap when you're ready"
→ it opens and records **exactly like the real product** → shows what a friend would
receive → **never sends, stays on the phone**. Teaches the core loop against the empty
home (the #1 tester complaint, 4 testers).

**DECISION D3 (confirm before building) — scripted vs AI coach:**
- **Scripted** (canned friend + canned clip, real capture UI, nothing sent): cheap/fast (M),
  deterministic + testable, no AI cost/latency, works offline, privacy-clean, patent-safe
  (local-only path), and it's exactly what the wireframe draws. Downside: one fixed moment,
  can't adapt.
- **AI coach** (assistant reacts to the user's real photo): more magical/adaptive, but a much
  bigger build (L+), ongoing LLM cost + latency, non-deterministic (moderation/QA burden),
  and — the real blocker — it must **process the user's actual media through an AI**, which
  collides with "never access or analyse user media" and the silent-capture privacy stance.
- **✅ DECIDED (Achia, 2026-07-21): build the SCRIPTED version now.** The AI coach is kept as
  a future roadmap item (see "Future — AI coach" below), **not built now.** Everything in this
  Feature 2 section specs the scripted v1.

### 🚨 Hard patent guardrail
The demo must **feel** like the real capture but must run on a **fully local, separate
path** — it must **never** call `sendMessage`, never seal, never `mark-viewed`, never
upload a reaction. Two acceptable implementations:
- (a) A dedicated `DemoReactionRecorder` that captures to a temp local file and deletes it;
  or
- (b) reuse the existing recorder **only** via a `demoMode` flag whose upload/seal calls are
  hard-short-circuited and covered by a test proving no network call fires.
Prefer (a) for a clean separation. **The patent regression suite must still pass unchanged**,
and add a **new test proving the demo path performs zero reaction upload / zero send.**

### Build
1. **New feature module** `app/lib/features/demo/` (presentation + a small controller). Do
   not bolt onto `receiver_message_widget.dart`.
2. **Assets:** bundle a canned "friend" media (a short video/photo) under `assets/demo/`,
   registered in `pubspec.yaml`. Also a demo friend name/avatar (e.g. "Maya" per wireframe).
3. **Flow (3 steps, per wireframe):**
   - **Step 1 — primer:** "Demo Reacti · just for you / Tap when you're ready." Single CTA
     "Open demo Reacti". Copy: "This practice reaction starts immediately and stays private
     on this phone."
   - **Step 2 — capture:** open the canned media; run the local front-camera record ("● REC
     00:03", no countdown / no preview / no retake — mirror the real capture timing, reuse
     the 4s window). This is the moment the just-in-time camera/mic prompt appears
     (coordinate with Feature 8c).
   - **Step 3 — reveal:** show the composite the way a friend receives it (original media +
     the user's reaction beneath), with **"Send your first Reacti"** as the next action.
     Copy: "The recording is never sent — it just shows what a friend would receive."
4. **Routing / one-time:** show the demo after signup + onboarding for first-time users;
   persist `kKeyDemoSeen` (new constant) so it never re-fires. Entry point sits after the
   onboarding-complete / login-success path in `loading.dart` / post-auth navigation. The
   "Send your first Reacti" CTA routes into the real first-send (or the invite flow,
   Feature 5) — pick the empty-state chat entry.
5. **Permissions:** camera/mic soft-ask right before Step 2 (Feature 8c pattern); if denied,
   degrade gracefully (skip capture, still show the explanation) — never hard-block signup.
6. **Analytics:** fire `demo_reaction_completed` on reaching Step 3 (Feature 4). Also a
   `demo_started` event on Step 1 CTA. Follow the allowlist; **never** upload or reference
   the captured demo media.

**Tests:**
- Widget: the 3-step flow advances; "Open demo Reacti" starts capture; Step 3 shows reveal +
  CTA; `kKeyDemoSeen` set after completion; demo doesn't re-fire when the flag is set.
- **Patent-critical:** a test proving the demo path issues **no** `sendMessage` and **no**
  reaction upload (mock the rx singletons / network and assert zero calls).
- Existing patent regression suite still green.

**Acceptance:** a fresh user, post-signup, gets the practice Reacti; it records locally,
shows the friend's-eye view, never sends, never uploads; sets `kKeyDemoSeen`; the real
capture flow and its tests are untouched.

### Future — AI coach (roadmap, NOT built now)

Captured so it isn't lost, but explicitly **out of scope for this plan.** Revisit only after
the scripted demo is live and the activation metric (Feature 4) shows the demo helps but
users still stall. Build the scripted v1 so it can grow into this without a rewrite:
- **Design seam now:** keep the demo flow behind a `DemoController`/strategy interface so a
  future `AiCoachDemo` can slot in beside `ScriptedDemo` without touching the capture path.
- **What the AI coach would add later:** a conversational guide that adapts to where the user
  stalls and can prompt them through their first *real* send.
- **Hard gates before it can ship (why it's "later"):**
  1. **Privacy/legal — the blocker:** any coach that "reacts to" the user's real photo/face
     means processing user media through an AI, which conflicts with "never access or analyse
     user media" and the patent's silent-capture stance. Needs a legal call (same counsel as
     DG1) + a design that keeps user media off any AI path (e.g. coach only guides, never
     ingests the user's face).
  2. **Cost/latency/moderation:** ongoing LLM cost, response latency, and safety review.
  3. **Reliability:** non-deterministic output needs guardrails + QA the scripted version
     doesn't.
- **Decision to reopen later:** scripted-only vs. scripted-then-coach, informed by real
  activation data. Track as a future `PLAN-ai-coach-*.md` when the time comes.

---

# WAVE 2 — growth loop + measurement

## Feature 5 — Simple personal invite  ·  `feat/personal-invite` (+ `feat/invite-connect`)  ·  M  ·  DECISION D4

**Goal:** non-Reacti contacts get an **Invite** button → **standard iOS share sheet** with a
prepared message → toast + row flips to "Invited" → after the invitee signs up they see
**"Jon invited you / Connect with Jon"** (one tap, never forced) → land in Jon's chat with
**"Send a Reacti"** as the next action. This is the **non-recording** invite — **no legal
block** (distinct from the on-hold viral demo in
`RESEARCH-BRIEF-viral-reaction-demo-2026-07-01.md`).

**Current state:** contacts matching + friend requests exist (`find_screen.dart` /
`friends_tab_screen.dart` / `search_screen.dart`). No share-sheet invite for non-users; no
post-signup connect. Contacts intro/priming from PLAN-ux Phase 5 (`_buildContactsIntro`,
`kKeyContactsSkipped`).

### Part A — Invite + share sheet (client-mostly)  ·  `feat/personal-invite`
1. **Three contact states** (per mockup — honor all three, don't collapse to two):
   - **on Reacti + already friend** → label **"Friend"** (no action).
   - **on Reacti, not yet friend** → **"Add friend"** button (existing friend-request path).
   - **not on Reacti** → **"Invite"** button (the new share flow).
2. On **Invite** tap → open the iOS **share sheet** via `share_plus` (add dependency) with a
   prepared message + invite link. Use the mockup's copy and `reacti.app/i/{CODE}` link
   format verbatim:
   > "{FirstName} invited you to Reacti!
   > Send photos and videos and see each other's genuine first reactions.
   > Get Reacti: reacti.app/i/{CODE}"
3. After the sheet is invoked, show a **toast** (mockup: **"Invite shared with {FirstName}"**)
   and flip the row to a greyed **"Invited"** state locally (persist invited contact ids in
   GetStorage, e.g. `kKeyInvitedContacts`, so it survives a reopen). No OS prompt beyond the
   share sheet.
4. The **invite link**: request a per-inviter link/token from the backend (Part B); if D4 =
   "plain link v1", the link is just the App Store URL with an optional `?ref={code}` query
   — **do not** put PII in the URL (privacy rule); use an opaque code that maps to the
   inviter server-side.

### Part B — Connect after signup (backend + client)  ·  `feat/invite-connect`
5. **Backend:** an invite endpoint that mints an opaque invite **code** bound to the inviter
   (`POST /invites` → `{code}`; `GET /invites/{code}` → inviter public profile). Store
   `invites(code, inviter_id, created_at, consumed_at)` (new migration, additive). On the
   invitee's **signup**, accept an optional `invite_code`; resolve → surface the inviter.
   Standard envelope; FormRequest validation; rate-limit minting.
6. **Client:** after signup + onboarding, if an invite code is present, show the connect
   screen (verbatim copy): title **"{Inviter} invited you"**, body **"Connect with
   {Inviter} and start sending real moments and reactions."**, primary **"Connect with
   {Inviter}"**, secondary **"Not now"** (never forced). "Connect" = one tap → create the
   friend link (reuse the existing friend/accept path) → route into that chat, which opens on
   a **"You're connected / Send something that deserves a real reaction / Send a Reacti"**
   empty state (matches the standard first-chat empty state).
7. **Analytics:** `invite_shared` (Part A, on share), `invite_opened` (Part B, when the
   connect screen shows), `invite_connected` (on tap). Feeds Feature 4 funnel.

**DECISION D4 — ✅ DECIDED (Achia, 2026-07-21): plain link v1 now, infra ready for paid later.**
Paid deferred-deep-link providers are out of budget for now, so ship **(b)** but build the
backend so **(a)** is a drop-in later with **zero schema/flow rework**:
- **v1 (build now):** the backend mints a real **opaque, inviter-bound invite code** (the
  `invites` table below) and the share link is `reacti.app/i/{CODE}`. Carry the code across
  install via a **universal link** when the app is already installed; otherwise fall back to a
  one-time in-app **"Who invited you?"** entry (or paste-the-link) right after signup. No paid
  service, no PII in the URL.
- **Later (no rework):** drop in a deferred-deep-link provider (Branch / Adjust / FDL
  successor) that auto-carries `{CODE}` through a fresh install → the *same* backend
  `GET /invites/{CODE}` resolves it and the *same* "Connect with {Inviter}" screen fires. The
  provider is an acquisition detail, not a data-model change — so v1 must treat the code as
  the single source of truth and never hardcode the manual-entry path as the only route.
- **Design constraint for Claude Code:** keep code minting/resolution + the connect screen
  **provider-agnostic** (one `InviteService` seam) so adding a provider later is config, not
  surgery.

**Tests:**
- Backend: mint code (auth required), resolve code (public inviter), signup consuming a code
  creates the pending connect, invalid/consumed code handled. `assertOk` + `success:true`.
- Client: Invite button appears only for non-Reacti contacts; tapping fires share + flips to
  "Invited" + persists; connect screen shows for a present code and "Connect" creates the
  friendship and routes to the chat.

**Acceptance:** non-user contacts show Invite → share sheet with prepared message → "Invited"
state; a new signup arriving via an invite sees "Connect with {Inviter}" and one tap
connects + opens the chat. No PII in URLs; no camera recording anywhere in this flow.

---

## Feature 4 — Beta activation funnel  ·  `feat/analytics-activation-funnel`  ·  S  ·  needs #2 & #5

**Goal:** the wireframe funnel — Signup → Demo done → Invite sent → Reacti sent → Delivered
— plus core events, and a primary metric: **% of new users who complete one full Reacti
loop.** "Measure behaviour — never access or analyse user media."

**Current state:** PostHog + Sentry live in prod (privacy-first: salted id, event allowlist,
opt-out app+backend; existing dashboards). Received-message hook `trackMessageReceived(...)`
exists; `reacti_sent` / `reaction_viewed`-type events exist. Event catalog + dashboards in
`docs/analytics/`.

**The mockup shows more than one funnel** — it has four analysis sections and both
activation AND retention tiles. Build all of it:
- **Top tiles:** New signups (with % change), First loop (%), **Sent another (%)**,
  **2nd within 7d (%)** — the last two are *retention*, not activation.
- **First-loop funnel** (exact step labels): **Signup → Demo done → Invite sent → Reacti
  sent → Delivered** (mockup values 100→81→70→65→61%).
- **Four dashboard sections:** ① Signup + onboarding ("into the app?"), ② Send + open +
  react ("loop complete?"), ③ **Time to loop ("how fast?")** — a time-to-first-loop metric,
  ④ Drop-off points ("where they stop?").

**Change:**
1. **Confirm/instrument the funnel events** (add any missing to the allowlist in
   `docs/analytics/`, additively):
   - `signup_completed` — verify it exists; add on OTP-verified/account-created if not.
   - `demo_reaction_completed` — from Feature 2 (Step 3).
   - `invite_shared` / `invite_opened` — from Feature 5.
   - `reacti_sent` — verify exists (media send).
   - `reaction_viewed` / delivered — verify exists (recipient opened + reaction returned).
   - **Retention:** a `reacti_sent_again` / second-loop signal so "Sent another" and "2nd
     within 7d" tiles can be computed (may be derivable from repeated `reacti_sent` per
     user + timestamps — confirm before adding a new event).
2. **Never** attach media, media URLs, or reaction content to any event — event names +
   non-PII props only (respect the salted-id + allowlist rules).
3. **Dashboard:** build the **first-loop funnel** + the **activation metric** ("% of new
   users completing one full loop", windowed 7d) **and** the retention tiles + the
   **time-to-loop** metric (median time signup → first delivered reaction), across the four
   sections above, in PostHog, mirroring the wireframe. Document events + dashboard in
   `docs/analytics/`.
4. Define the **north-star** with Achia (e.g. "% of new installs that send or receive their
   first reaction within 24h") so #1/#2 are measured against it.

**Tests:** analytics is config/instrumentation — verify events fire in staging with correct
(non-PII) props; add a lightweight unit test around any new client tracking helper.

**Acceptance:** the funnel renders end-to-end in PostHog once #2 and #5 ship; every event is
allowlisted and media-free; the activation metric is defined and charted.

---

# WAVE 3 — engagement mechanic (after DECISION D1)

## Feature 6 — Group react-to-unlock + "Unlocked reactions" reveal  ·  `feat/group-react-to-unlock`  ·  M  ·  D1 ✅ BUILD (Achia, 2026-07-21)

**Goal:** in a group, others' reactions stay **locked** until you react to the original
("🔒 3 reactions waiting — reacting to the original is the only way in"); once you react,
everyone else's reactions **unlock**. Sender still sees each reaction as it arrives.

**Mockup fine-print (use verbatim):** the original is sender-labeled at the top —
**"Mum sent a video Reacti · 0:18"**; the locked state shows the media, then
**"🔒 3 reactions waiting / Reacting to the original is the only way in."** with an
**"Open and react"** button. The reveal (step 2) is headed **"Unlocked reactions"** and is a
**vertical stacked list of member rows** (Jon / Geoff / Lior, one showing a ♥) — **not** a
side-by-side grid. (My earlier draft said "side-by-side grid" — that was Shai's separate
ask; **follow the wireframe's stacked list**. A grid is an optional later variant, not v1.)

**DECISION D1 — ✅ BUILD (Achia, 2026-07-21).** Real behavior change to the group flow,
approved. Caution to honor in QA (from triage): test it doesn't overly frustrate people who
just want to watch — the gate must never block *sending*, only *viewing others'* reactions.

### 🚨 Patent guardrail
This sits on the reaction flow. The **viewer's own reaction is still captured by the
existing silent path unchanged** — this feature only **gates the visibility** of *others'*
reactions in a group. Do **not** alter capture/seal/mark-viewed/upload. Re-run the patent
suite; the EP4 group-inbox integration harness (`enhancement-plan.md` EP4) is the right test
bed — build/extend it if not present.

**Current state:** group chat in `group_inbox_screen.dart` (onEvent ~L426) + `GroupMessage`
model; group reactions render today without a gate (which is exactly Jon's complaint — you
can see others' reactions before sending your own). Backend group message + reaction storage
via the chat services.

**Change:**
1. **Backend — gate others' reactions:** for a sealed group original, the list of *other
   members'* reactions is only returned to a viewer **once that viewer's own reaction is
   recorded**. Add a `viewer_has_reacted` computed flag + withhold the others' reaction
   payload (or return a locked count only, e.g. `reactions_waiting: 3`) until it's true.
   Implement in the group conversation resource/service (mirror the viewer-relative accessor
   pattern noted for `Chat`). Keep it **additive** — sender-facing "see each as it arrives"
   is unchanged.
2. **Client — locked state:** in the group inbox, render the wireframe's **"N reactions
   waiting / reacting to the original is the only way in"** + an **"Open and react"** CTA
   when `viewer_has_reacted == false`. After the viewer's reaction is captured (existing
   path), refresh → **unlock**.
3. **Client — "Unlocked reactions" reveal:** once unlocked, show an **"Unlocked reactions"**
   heading followed by a **vertical stacked list** of member reaction rows (Jon / Geoff /
   Lior per wireframe), each tappable to play. Not a grid.
4. **Edge cases:** a member who leaves; a viewer who is the sender (already sees all); a
   group where nobody else has reacted yet (show "be the first"); make sure the gate never
   blocks *sending* — only *viewing others'*.

**Tests:**
- Backend: a viewer who hasn't reacted gets only the waiting count, not others' reaction
  media; after recording a reaction, the same query returns the unlocked set; sender always
  sees all. `RefreshDatabase` feature tests.
- Client (EP4 harness): locked placeholder shows with the right count; capturing a reaction
  transitions to the "Unlocked reactions" list; patent regression green.

**Acceptance:** in a group, others' reactions are hidden behind "N reactions waiting" until
the viewer reacts; reacting unlocks the "Unlocked reactions" list; the sender's incremental
view and the silent-capture path are unchanged.

---

# WAVE 4 — cleanup (after the loop feels good)

## Feature 8b — "Send Reacti" CTA + visible attach icon  ·  `feat/composer-send-reacti-cta`  ·  S–M

**Goal:** make sending a photo/video Reacti obvious even from plain text — a dedicated
**"Send Reacti"** primary button plus a **visible attach icon** in the chat composer (per
wireframe step 2 of Delivery 8).

**Current state:** composer `app/lib/features/chat/presentation/widget/send_message_widget.dart`
(`_handleSend` ~L280) has a text field + attach entry (paperclip → Gallery/Camera sheet).
Empty-state "Send your first Reacti" already exists in the chat list.

**Change:**
1. Add a clearly-labeled **"Send Reacti"** action in the composer (per wireframe, a filled
   lime pill left of the text field) that opens the media picker sheet (the existing
   Gallery/Camera flow) — i.e. the primary path to a media Reacti, not hidden behind a small
   paperclip.
2. Keep a **visible attach icon** alongside the text field so photo/video is discoverable
   even mid-typing. Don't remove the current attach entry; make it prominent.
3. Sending plain text stays as-is; this is purely making the media path obvious. No change
   to send internals or seal behavior.

**Tests:** widget test that the "Send Reacti" button opens the media sheet; `flutter analyze`
clean. Screenshot.

**Acceptance:** the composer shows an obvious "Send Reacti" button + visible attach icon;
both route into the existing picker; text send unchanged.

---

## Feature 8c — Just-in-time camera/mic permission  ·  `feat/jit-permissions`  ·  S–M  ·  overlaps EP4

**Goal:** ask for camera/mic **only when the feature is used** — the OS prompt appears at the
moment a user opens a Reacti / starts the demo, with a friendly primer first (per wireframe
step 3 of Delivery 8: "Reacti needs camera and microphone only when you open a Reacti").

**Current state:** permission asks are abrupt today (onboarding brief §2). `enhancement-plan.md`
EP4 already lists "check camera/mic permission before recording". Contacts permission priming
already handled (PLAN-ux Phase 5 / QW5).

**Change:**
1. Add a lightweight **soft-ask primer** (sheet/screen) shown **immediately before** the
   first camera/mic use — on first Reacti open and on the demo (Feature 2 Step 2) — using
   `permission_handler`. Copy: "Reacti needs camera and microphone only when you open a
   Reacti." Then trigger the OS prompt.
2. Persist that the primer was shown (`kKeyCamMicPrimerShown`) so it's a one-time soft-ask;
   subsequent uses go straight to the OS/permission state.
3. Handle **denied**: show a gentle "enable in Settings" path; **never** hard-block the app
   or signup. Route the just-in-time check through the pre-record permission point EP4
   introduces so there's a single choke point.
4. **Patent guardrail:** this is a **pre-prompt around** the capture, not a change to the
   silent capture itself. Do not add any delay/UI *inside* `recordVideoSilently`. Re-run the
   patent suite since it's adjacent to the capture trigger.

**Tests:** widget test that the primer shows once then sets the flag; a denied-permission path
degrades gracefully; patent regression green.

**Acceptance:** camera/mic is requested only at first use with a friendly primer; denial is
handled softly; the silent capture path and its tests are unchanged.

---

## Feature 8a — Merge Friends + Requests into one People tab  ·  D2 ✅ HELD (Achia, 2026-07-21)

**Goal (wireframe):** combine Friends + Requests into a single **People** tab
(Chats / People / Profile).

**Why it's on hold:** we **just** shipped a 4-tab bar (Chat / Friends / Request / Profile,
PR #252) in the UX-fixes batch. This partly **reverses** that. **Do not build without
DECISION D2.** If approved: merge the Friends and Requests screens into one **People** tab
with a Friends/Requests segmented control (the Requests count badge moves onto the segment),
collapsing the bottom bar to 3 tabs. Requires a nav pass and ideally an A/B, since it churns
navigation twice in a row. **Default: keep the current 4-tab nav; revisit after the activation
work lands.**

---

## Decisions to lock before the affected wave

| ID | Decision | Blocks | Default in this plan |
|----|----------|--------|----------------------|
| D1 | Group react-to-unlock — build or hold? | Feature 6 (Wave 3) | ✅ **DECIDED 2026-07-21: BUILD it** |
| D2 | People-tab merge vs keep 4-tab nav | Feature 8a | ✅ **DECIDED 2026-07-21: keep 4-tab, hold 8a** |
| D3 | Demo: scripted bot vs AI coach | Feature 2 (Wave 1) | ✅ **DECIDED 2026-07-21: SCRIPTED for v1; AI coach kept as a future roadmap item, not now (see Feature 2 → "Future")** |
| D4 | Invite connect: paid deep-link vs plain link v1 | Feature 5 Part B | ✅ **DECIDED 2026-07-21: plain link v1, build code infra for later paid deep-link** |
| D5 | Onboarding imagery | Features 1 & 7 | ✅ **DECIDED 2026-07-21: KEEP the carousel (it's good) — just replace the current UNRELATED images with related, real Reacti imagery. Profile replay reopens the same carousel.** |
| — | North-star activation metric | Features 1/2/4 | Confirm with Achia |

## Suggested execution order

Wave 0 (`feat/chat-list-preview-labels`, `feat/profile-how-reacti-works`) → Wave 1
(`feat/demo-reacti`) → Wave 2 (`feat/personal-invite` + `feat/invite-connect`, then
`feat/analytics-activation-funnel`) → Wave 3 (`feat/group-react-to-unlock`) → Wave 4
(`feat/composer-send-reacti-cta`, `feat/jit-permissions`) → **LAST:
`feat/onboarding-copy-refresh` (Feature 1) once Achia delivers the 3 carousel images.**
(`feat/people-tab` only if D2 reopens.) One PR per feature; ship each to staging (TestFlight
from `develop`) before stacking the next.

## Cross-references

- Triage/overview: `docs/PLAN-wireframe-deliveries-2026-07-21.md`, `docs/FEEDBACK-triage-2026-07-14.md`
- Onboarding depth/coach-mark + north-star: `docs/RESEARCH-BRIEF-onboarding-and-first-use-2026-07-01.md`
- Return-to-intro (QW3), avatar-enlarge, flash, discard-reopen: `docs/PLAN-quick-wins-tester-feedback-2026-07-14.md`
- Media multi-send (separate from Feature 3): `docs/PLAN-whatsapp-media-2026-07-16.md`
- Nav history (4-tab): `docs/PLAN-ux-fixes-2026-06-28.md`
- Viral demo (legally-blocked cousin of Feature 5): `docs/RESEARCH-BRIEF-viral-reaction-demo-2026-07-01.md`
- Patent/permission hardening + EP4 harness: `docs/enhancement-plan.md`
- Analytics events + dashboards: `docs/analytics/`, `docs/PLAN-analytics-stats-2026-06-14.md`

---

## Appendix A — verbatim copy & mockup fine-print

These are the exact on-screen strings from the mockups. Use as-is (hardcoded literals per
conventions); adjust names/counts to real data.

**Feature 1 — Onboarding.** Slide 3 isn't just an illustration — it renders the **real chat
pair**: a "You sent a Reacti" bubble with the media + timestamp + double-tick, and the
recipient's reaction **beneath** it labeled "{Name}'s reaction" with its own timestamp.
Mirror the real chat layout, not a generic graphic.

**Feature 2 — Demo Reacti (verbatim).** Screen header "Welcome to Reacti".
- Step 1: **"DEMO REACTI · JUST FOR YOU"** / **"Tap when you're ready."** / "First time here?
  This practice reaction starts immediately and stays private on this phone." / CTA
  **"Open demo Reacti"**.
- Step 2: recording chrome **"● REC 00:03"** and the line **"No countdown. No preview. No
  retakes."** (The mockup shows a 3s frame; **use the real 4s capture window**, not 3.)
- Step 3: sections **"Demo Reacti"** (the original) + **"● Your reaction"**, CTA **"Send your
  first Reacti"**, footnote **"This is what your friend receives."**

**Feature 3 — Chat list.** The list header shows a **time-based greeting** —
**"Good Morning, {FirstName}"** (mockup: "Good Morning, JonJon"). Check whether this exists;
if not, it's a tiny addition (greeting by local time). Empty state: **"No Reactis yet / Send
something that deserves a real reaction. / Send your first Reacti"**. Row labels (with icons):
📷 **"New photo Reacti"**, 🎬 **"New video Reacti · 0:24"**, ✓ **"Reaction received"**; unseen
rows carry a lime dot + the "Unseen" chip count. Mockup note on step 4: **"Opening itself
already works — no extra explanation screen needed"** → this feature is *only* the labels,
build nothing else here.

**Feature 5 — Invite (verbatim).** Share message + `reacti.app/i/{CODE}` link (see Part A).
Toast **"Invite shared with {FirstName}"**. Connect screen: **"{Inviter} invited you"** /
"Connect with {Inviter} and start sending real moments and reactions." / **"Connect with
{Inviter}"** / **"Not now"**. Post-connect chat empty state: **"You're connected / Send
something that deserves a real reaction / Send a Reacti"**.

**Feature 6 — Group (verbatim).** **"{Sender} sent a video Reacti · 0:18"** / **"🔒 3
reactions waiting"** / "Reacting to the original is the only way in." / **"Open and react"**;
reveal heading **"Unlocked reactions"** over a stacked member list.

**Feature 7 — Profile (verbatim).** Section **"ACCOUNT"**; rows in order: **"Edit Profile ›"**,
**"How Reacti works"** with trailing **"Replay ▶"**, **"Notifications"**, **"Privacy"**.
Header shows avatar, name, "@{username}", and **"{n} Friends · {n} Groups"**.

**Feature 8b — Composer (verbatim).** A filled **"Send Reacti"** pill next to a **"✎
Message…"** field with a visible attach icon.

**Feature 8c — Just-in-time permission (verbatim).** Primer (shown as part of the demo):
**"Ready for your demo?"** / **"Reacti needs camera and microphone only when you open a
Reacti."**, then the OS dialog (which iOS renders): "'React' Would Like to Access the Camera
/ Ask at the moment the feature is used". Request **camera + microphone together** at that
moment. Note: because the primer says "Ready for your demo?", the **first** camera/mic ask
naturally lands inside Feature 2's demo — build 8c and 2 to share one primer.

---

## Appendix B — related carousel imagery (D5): shot list for Achia to capture

D5 keeps the carousel and just needs **related** images. Claude Code can't run the app, so
**Achia captures these** (a ~10-min job on device). The **3 stills are the deliverable**
(they replace the unrelated carousel images in Feature 1); the optional video at the end is a
future nice-to-have, not required. Capture in the target theme (dark, optionally light) at
device resolution; use faces you're allowed to show or your own.

**The 3 stills (carousel — required):**
1. **Send the moment** — the composer with a real photo/video staged, about to send.
2. **Catch the real reaction** — the recipient's open-and-capture moment (the sealed media
   opening; the capture indicator visible). Use a demo/self account so no real reaction is
   exposed.
3. **No retakes. Just real.** — the real chat pair: "You sent a Reacti" + the media, with the
   recipient's reaction **beneath** it and timestamps (exactly slide 3 of the mockup).

**Optional future video (~20–30s), one continuous screen-recording of the loop — not needed for v1:**
- (0–6s) Open a chat → attach a photo → tap **Send Reacti**.
- (6–14s) Switch to the recipient side → tap the sealed message → it opens and the front
  camera captures the reaction (show the capture indicator; this is the "aha").
- (14–24s) The reaction sends back automatically and appears beneath the original — show the
  pair.
- (24–30s) End on the chat list showing "Reaction received" / "New photo Reacti" labels.
- Optional: a 3–5 word caption per beat ("Send." / "They open it." / "You get their real
  reaction."). No music required.

**Delivery:** drop the 3 stills in `app/assets/onboarding/` and register in `pubspec.yaml`;
Feature 1 swaps them into the carousel. (If the optional video is made later, it can be added
to the profile row as an upgrade — not part of v1.)
