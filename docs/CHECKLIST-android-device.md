# Android device checklist

Companion to `docs/PLAN-android-and-play-store-2026-09-28.md`. For every step
it lists what CI already proves automatically, and what only a real phone can.
The last section is the **full end-to-end run**: do it before the closed test
opens (plan Step 11) and again before launch (Step 15), so the pieces are
proven *together*, not only one by one.

## How the testing works

| Layer | Runs | Proves |
|---|---|---|
| Unit and widget tests (`app/test`, `backend/tests`) | every PR | the logic, on every platform |
| **Build Android (release)** | every PR | the release build compiles and shrinks; exact permission list (`app/android/permissions.allowlist`); camera optional; notification icon present |
| **Android device checks (emulator)** | every PR | on a real Android 14 OS: release app launches without crashing, no permission prompt at launch, notification channel exists, a real front-camera clip records with audio, the gallery opens the system photo picker |
| **Device checks below** | per step, on the device kit | what no emulator can: real push delivery, real faces, real links, two phone brands |

Every automated check keeps running on every later PR, so a later step that
breaks an earlier one turns CI red immediately.

**Device kit:** one Samsung and one Pixel, at least one on Android 14+, and
an iPhone with the staging build to talk to. Install the Android staging
build from Firebase App Distribution (after Step 2). Record each run in the
step's PR: date, phone, build number, pass/fail, a screenshot or recording.

---

## Per step

### Step 3: permissions
Automatic: no prompt at launch; exact permission list.
On the phone, fresh install each time:
- [ ] Open the app: **no** camera or microphone prompt before sign-up.
- [ ] First Reacti (or the demo): the explanation dialog, *then* the prompt.
- [ ] Deny once: no crash; the "enable in Settings" hint opens Settings.
- [ ] Deny twice ("Don't ask again"): no crash; opening a Reacti still works
      (it just records nothing).
- [ ] Android 13+: the notification prompt appears once.

### Step 5: the reaction (patent flow)
Automatic: front-lens choice (unit); a real front-camera clip with audio
(emulator); the patent-flow harness.
On **both** phones, with the iPhone:
- [ ] iPhone sends a photo, Android opens it: the reaction that arrives is
      **the Android user's face**, upright, with sound.
- [ ] Same in reverse (Android sends, iPhone opens).
- [ ] Same in a group.
- [ ] Press Home in the middle of a reaction: no crash; the next Reacti
      records normally.

### Step 6: notifications
Automatic: channel exists at high importance (emulator); payload channel and
priority (backend); app, manifest and backend agree (unit); icon survives the
release build.
On the phone, iPhone sends a message each time:
- [ ] App open: banner, Reacti silhouette icon (not a white square), no
      double sound.
- [ ] App in background: banner with sound.
- [ ] App swiped away: banner with sound; tapping opens **that** chat.
- [ ] iPhone still gets sound and badge from an Android sender.

### Step 7: gallery
Automatic: system picker opens with no permission prompt (emulator); review
screen logic, photo vs video, edits, caption (widget tests); no media
permission in the app.
On the phone:
- [ ] Gallery: Android's own picker opens, **no permission prompt**.
- [ ] Pick 1 photo, send. Then 5 mixed photos and videos with one caption.
      The iPhone gets them all, the caption once, every one blurred and
      reacting.
- [ ] Edit a photo on the review screen, send: the edited version arrives.
- [ ] Profile photo and group photo pickers also open the system picker.

### Step 8: invite links
Automatic: Play button only for Android and only when configured (backend).
On the phone (after App Links land, Steps 2 and 4):
- [ ] With the app installed: an invite link opens **the app**, at the invite.
- [ ] Staging link opens the staging app, never production.
- [ ] Without the app: the page shows the Google Play button; the web demo's
      camera works in Chrome.

---

## Full end-to-end run (before Step 11 and again before Step 15)

Two new accounts, one Android phone and one iPhone, fresh installs, nothing
pre-configured. The whole loop must work in one go:

1. [ ] Android: install, sign up (age gate), the walkthrough runs.
2. [ ] iPhone sends an invite link; Android opens it and the two become friends.
3. [ ] iPhone sends a photo. Android (app closed) gets a banner, taps it, the
       chat opens, the photo unblurs, and **the iPhone receives Android's
       reaction**.
4. [ ] Android sends 3 photos from the gallery with a caption; the iPhone opens
       one and Android receives **its** reaction.
5. [ ] Group of three (two phones plus a third account): send, open, reactions
       arrive for everyone.
6. [ ] App lock on Android: lock, background, return, unlock with fingerprint,
       then with the passcode.
7. [ ] Delete the Android account; signing in again with it fails.
8. [ ] Sentry: no new Android crash. PostHog: the run's events show
       `platform: android`.

Any failure stops the run: fix it, add an automatic check for it if one is
possible, and restart from 1.
