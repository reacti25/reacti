# Changelog

All notable user-facing and operational changes to Reacti (app + backend),
newest first. Versions follow the app's `pubspec.yaml` marketing version.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
