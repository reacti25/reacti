# Changelog

All notable user-facing and operational changes to Reacti (app + backend),
newest first. Versions follow the app's `pubspec.yaml` marketing version.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [1.6.0] — Prepared 2026-09-05

**Theme: getting in, getting found, and knowing whether any of it works.**
28 commits. App-first release; the production backend deploy stays gated until
the new app is live. Build **1.6.0+19**.

> **RELEASE GATE, not engineering.** This is the first production build that
> collects analytics, so the App Store **App Privacy** declaration and the
> published privacy policy must be updated *before* the build is submitted.
> The declaration attaches to the version, so it cannot be corrected
> afterwards. Exactly what to tick is in
> `docs/analytics/app-store-privacy-declaration.md`.

### Added
- **Face ID / passcode lock** in front of the app, with a passcode fallback and
  a delay setting. It locks the app; it is not a login.
- **Three separate searches**: friends and contacts stay wide open, and only
  stranger search is restricted (username prefix, graph-ranked, capped).
- **Contacts search** on the Contacts tab.
- **Delete a conversation**, and the walkthrough replay now lands on Chat.
- **Screen-lit front-camera photos**, since the front lens has no flash.
- **Analytics**: the activation funnel with time-to-value, the walkthrough and
  demo, the invite loop end to end, coarse country, rolling retention, what the
  OS permission dialogs came back with, sign-in outcomes, session length, and
  the deliberate ways people leave. Two commands read all of it. No message
  text, media, camera footage, names, emails or precise location, and an
  off switch in Settings, About & Data, Usage Data.

### Changed
- **The walkthrough** now lands on the tab the next step is on, covers the
  Friends tab for an empty account, and shows the username search as well as
  contacts.
- **The photo editor** is laid out like WhatsApp (tools top, confirm bottom).
- **Both demos** now tell you to keep the phone at face level, like a video
  call, before the camera starts rather than after.

### Fixed
- **Unfriend and leave group** actually work, and two people can be friends
  again after unfriending.
- **Contacts sharing is reversible both ways**, with a route to Settings from
  every dead end.
- **Invite links** no longer bounce in and out of the app, and each app claims
  only its own host.
- **The app lock** only engages when the app was genuinely backgrounded.
- **The practice Reacti** shows once even if you back out of it.
- **The invite landing page** paints to the edges: a white band showed below it
  on iOS because the background was a gradient with no colour underneath.
- No long dashes anywhere in user-facing copy.

### Notes for this release
- **No API response shapes changed.** Zero controllers and zero API resources
  were touched, and no contract test needed updating, so the failure mode that
  broke production in the past (a new backend answering an old app in a shape
  it cannot read) is not present in this batch.
- One additive migration, `add_funnel_counters_to_invites`, which adds counter
  columns to the `invites` table. It runs with the backend deploy, after the
  app is live.
- iOS minimum stays at 16.0, unchanged since 1.4.0.

## [1.5.0] — Prepared 2026-08-22

**Theme: getting a new person from install to their first Reacti.** 93 commits.
App-first release; the production backend deploy stays gated until the new app
is live. Build **1.5.0+18**.

> ⚠️ **Signup now requires a date of birth and rejects under-16s.** The backend
> enforces this, so an older app build that doesn't send the field will fail to
> register — the app **must** reach the App Store before the backend deploys.
>
> ⚠️ **Existing accounts have no recorded age.** The one-time confirmation for
> them (age gate A4) is still unbuilt, parked on the lawyer question about what
> happens to a declining user's existing chats and media.

### Added
- **In-app walkthrough** replacing the onboarding carousel: a "How a Reacti
  works" card, then tips that appear on the real screens — pick someone, send a
  Reacti, sent & sealed. Replayable any time from Profile.
- **Demo Reacti** — a private practice Reacti for first-timers, replayable from
  Profile. Never sends anything.
- **Invites** — personal invite links, a landing page that plays an interactive
  demo of the app, tap-to-open via Universal Links, direct WhatsApp invites to a
  contact, and per-contact invite states.
- **Age gate** — date of birth on signup, minimum 16, enforced on both the email
  and Google sign-in paths.
- **Group react-to-unlock** — a group member reacts to unlock the media.
- Camera/microphone permission primer shown just before the first real capture,
  so the OS prompt never arrives cold.
- `signup_completed` analytics event, the anchor of the activation funnel.

### Changed
- Chat list shows what the last message actually was — typed labels, and 🫣 / 🤭
  for a reaction waiting versus already seen.
- Composer has a visible attach icon and a "Send Reacti" call to action.

### Fixed
- Google sign-in dropped the email address when creating an account.
- Invite sharing: unreliable taps, a missing iOS share-sheet anchor, and errors
  that failed silently.

## [1.4.0] — Prepared 2026-07-20

**Theme: sending media feels like WhatsApp, and notifications finally work.**
The largest batch since launch (67 commits). App-first release; the production
backend deploy stays gated until the new app is live. Build **1.4.0+17**.

> ⚠️ **Raises the iOS minimum from 13.0 to 16.0** (required by the media
> rebuild). iPhone 7 and older can no longer run the app. Accepted by Achia
> 2026-07-20.
>
> ⚠️ **Ships without the DG1 recording-consent flow**, which is absent from the
> code (reverted by `7c49910` before the first release). Achia chose to ship
> without it while the app is in **closed friends-only testing**. Scoped to
> closed testing only — see `NEEDS-ACHIA.md` before any public launch.

### Added
- Multi-select photo/video send with a shared caption, in a sheet picker that
  drags up to full screen, plus a photo editor behind the pencil.
- View-once media — photos/videos that disappear after one open (1:1 and group).
- Push notification sound; tapping a notification opens the correct chat;
  app-icon badge counting conversations with anything unseen.
- Long-press message actions: edit within 10 minutes, forward to several chats,
  delete-for-me, exact seen time.
- Camera flash toggle; the camera re-opens after discarding a shot.
- Friend discovery by username; tap a profile or chat-header photo to enlarge.
- Haptic feedback on send/receive with a Sound & Vibration setting.

### Changed
- Sent media appears instantly (optimistic send) instead of after the upload
  completes — the visible delay on slow connections is gone.
- Long 1:1 chats load older messages as you scroll.
- Exactly one sound per received message: the OS tone outside the app, the
  in-app tone inside it — never both.

### Fixed
- A rotated FCM token now re-registers itself, so push can no longer stop
  working silently until the next login.
- iOS push was completely silent — the payload carried no `aps.sound`.

## [1.3.2] — Prepared 2026-07-08

**Theme: videos that don't break, and everything a bit faster.** App-first
release; the production backend deploy stays gated until the new app is live.
Build **1.3.2+16** — supersedes `1.3.1+15` on the App Store. Backend changes are
additive (the group Unseen count reads existing per-message state), so the
currently-live app keeps working.

### Fixed
- **Videos no longer freeze or black out.** After watching several videos/
  reactions the app could, after ~a minute, freeze or black out every video at
  once. Root cause was a listener leak on the shared video players that starved
  iOS's video decoding; it's fixed and locked with a regression test.
- **Front camera no longer sticks.** Switching to the front camera in the
  in-app camera could get stuck — fixed.
- **Group "Unseen" now counts unopened media.** A group with sealed media you
  hadn't opened yet wrongly dropped out of Unseen once you opened the thread;
  it now stays Unseen until you actually open the media (matching 1:1 chats).

### Faster
- **Photos and videos are compressed before sending** — they upload faster,
  load faster, and videos play more smoothly.
- **Faster app start** — independent startup steps now run in parallel.
- **Smoother video playback** — less CPU/battery while a video plays.
- **1:1 chats load older messages on scroll** (pagination) so opening a long
  conversation is quicker.
- **Faster media delivery worldwide** — media is now served through a global
  edge cache (Cloudflare, operational/infra), so first loads are much faster for
  users far from the server. Applies to the live app too.

### Improved
- **Groups with no photo show a friendly "people" icon** — on the chat list,
  inside the group, and on the group-details screen — and group details render
  correctly in light mode.

## [1.3.1] — Prepared 2026-07-04

**Theme: a proper light mode, a WhatsApp-style media flow, and read receipts
that update live.** App-first release; the production backend deploy stays
gated until the new app is live. Build **1.3.1+15** — supersedes `1.3.0+14` on
the App Store with a new version + build number. Backend changes are additive
(new broadcasts + additive response fields), so the currently-live app keeps
working.

### Added
- **Light / Dark / System theme.** A real light mode across the app, chooseable
  in Settings (System / Light / Dark), with a one-time appearance picker on
  first run after sign-up. Dark mode is unchanged.
- **WhatsApp-style media sending.** A clean picker sheet (Gallery / Camera with
  labelled icon circles), an in-app gallery grid, a unified in-camera Photo/Video
  toggle, and a preview-and-confirm step before a photo/video is sent. Still one
  file per send.
- **Dedicated Settings screen.** Preferences moved off the profile tab into a
  grouped Settings screen (Account / Privacy / Appearance / About & Data); the
  profile page is slimmed to header + stats + entry points.
- **Full-screen media.** Tap a received image to open it full-screen with
  pinch-to-zoom.
- **Live Permissions page.** The Permissions screen now reflects real OS grant
  status and its buttons work (request, or open Settings).

### Fixed
- **Read receipts update live.** The single→double check now upgrades the moment
  the recipient sees the message (1:1 and group), instead of only after both
  people leave and re-enter. In groups the double-check appears once **all**
  members have read.
- **Reaction "watched" dot is correct and live.** The grey→green dot greens the
  moment the **original media sender** plays the reaction — in groups it no
  longer greens falsely when any other member opens the chat, and in 1:1 it now
  greens on the sender's first watch.
- **Group chat framing.** Removed the dark letterbox band above/below the group
  conversation in light mode (it now matches 1:1).
- **Light-mode legibility** across auth, OTP boxes, form fields, user search,
  edit profile, reply-to-image quotes, and the reply banner.
- Small copy/label fixes: bottom-nav "Requests", the "Blocked Users" screen
  title.

### Changed
- Removed the unused location permission (resolves Apple ITMS-90683) and a batch
  of dead code — behaviour-preserving, test-proven.

### Notes
- No breaking API-shape change; **PHP Tests + Analyze & Test green**, backend
  additive only. The patent silent-recording path is unchanged.

## [1.2.1] — Unreleased (prepared 2026-06-26)

**Theme: media feels instant + chat fixes.** App-first release; the production
backend deploy stays gated until the new app is live. (Analytics has been live
since 1.2.0 — unchanged here.) Build **1.2.1+13** — `1.2.0+12` already shipped to
the App Store, so this supersedes it with a new version + build number.

### Added
- **Media feels instant.** Received photos/videos open immediately and are
  **pre-loaded on arrival**, so opening is near-instant (load time p90 down from
  ~1.2s to well under it). Images decode at screen size, not full resolution.
- **One-tap video.** A received video plays on the single tap that opens it
  (was two taps) — and the silent reaction is now captured against the *playing*
  video, not a frozen first frame.
- **Authentic reaction timing (off by default).** The silent reaction starts
  recording when the media is actually painted on screen (vs. while loading), so
  it overlaps the real media (~100%). Behind the off-by-default
  `reaction_trigger_on_paint` flag — inert until a production flag enables it.

### Fixed
- A sent photo/message no longer **vanishes after sending** (1:1 and group) —
  it stays visible without leaving and re-entering the chat.
- **Group reactions** no longer arrive **sealed**; they show directly like 1:1.

### Notes
- No API-shape change; **Backwards-compat + Contract suites green**. The only
  patent-mechanic change (record-on-paint) is flag-gated and **off in prod**.
- Reaction upload-retry is intentionally held back (rides a later release).

## [1.2.0] — Released 2026-06-19

**Theme: production analytics goes live** — real, privacy-first product &
performance numbers, plus a meaningful opt-out.

### Added
- **Privacy-friendly analytics (live in this release).** The app and backend
  now produce pseudonymous product/usage and performance numbers — **no names,
  emails, message content, media, or location**. User ids are **hashed with a
  secret production salt** (distinct from the test environment), and data is
  stored in the **EU** region.
- **"Usage Data" opt-out** in the app that actually works end-to-end: turning it
  off stops **both** the app and the server from sending anything tied to you;
  turning it back on resumes. Default is on.
- **Performance & authenticity metrics** (metadata only): media load time, media
  exposure, screen render / time-to-interactive, frame smoothness, and the
  reaction↔media **overlap** metric that evidences a reaction was captured while
  the media was actually on screen.

### Changed
- **Reset-password code handling** was de-duplicated into a single internal
  routine — **identical behavior** (same emails, same codes), just one source of
  truth. Pinned by existing tests.
- **Code clean-up ("ponytail" pass), invisible to users:** ~890 lines of dead
  code removed across 12 small, behavior-preserving, test-proven changes.

### Removed
- Unused `flutter_slidable` dependency; dead mailables (`HelpAndSupport`,
  `ContactMail`, `SendReportMail`, the superseded `RegisterOtpMail`) + their
  orphaned views; dead helper methods, widgets, and a fully commented-out file.

### Not included (deliberately parked)
- **Silent-recording consent flow (DG1)** — stays on its own branch pending
  legal copy; not in this release.
- **Mailtrap test email** — staging-only; production keeps its own real mail
  server, unchanged.

### Notes
- **No API-shape change** — the live-app backwards-compatibility guard and the
  contract tests stay green; the patented send→record→reaction flow is
  **byte-for-byte unchanged**.
- Analytics is **default-off** unless the production build/deploy explicitly
  supplies the keys (production 1.2.0 was built with them, so analytics is live).

## [1.1.0] — 2026-06-14

First production release of the rebuilt Reacti app (consent-free), shipped
app-first ahead of the matching backend.

### Security
- Removed publicly-reachable maintenance URLs that could **wipe the database**.
- **Rate-limited** login/OTP screens (the 4-digit code was brute-forceable).
- OTP codes are **no longer returned in API responses** (closed an
  account-takeover path).
- Removed an app-wide setting that **disabled HTTPS certificate checking**.
- Login token now stored **encrypted** and **fully erased on logout**; locked
  down CORS, upload-folder permissions, admin settings routes, and made session
  cookies HTTPS-only.

### Fixed
- A failed load now shows **"Couldn't load… / Retry"** instead of a **blank
  screen** (chat list, conversation, group).
- A picked photo/video now appears **inside the message box** with a lit-up send
  button, so it's clear it isn't sent until you tap send.

### Changed
- Patent flow (silent reaction recording) hardened internally — de-duplicated,
  guarded against a crash on malformed messages, with failure logging —
  **behaves the same**, just safer.
- Added a full automated test safety net (incl. the patent-flow end-to-end
  harness), an enforced coverage floor, and the CI gates.
