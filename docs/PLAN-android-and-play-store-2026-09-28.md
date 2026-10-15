# Plan — Android support and the Google Play Store

**Written 2026-09-28. Revised 2026-09-29 (twice). Status: NOT STARTED.**
Achia has confirmed: there is **no Play Console account yet**, and **twelve
testers will be available**.

Reacti is iOS-only in production (1.6.0+19). An `android/` folder exists and
the app compiles to a debug APK in CI, but it has never run as a release build,
cannot be uploaded to Play, and several parts of the loop (invites, push,
gallery) are iOS-shaped.

The plan is **16 steps**. Each ends in a **gate**: a concrete check that
proves the step works on its own. **A step is not done, and the next one does
not start, until its gate passes.** A problem introduced in step 3 shows up in
step 3, not in week six.

---

## What the second review changed (2026-09-29)

Every claim below was checked against the code, the plugins' own manifests in
the pub cache, or Google's documentation. Several claims in the earlier
versions were wrong.

1. **Wrong: "CAMERA, RECORD_AUDIO and POST_NOTIFICATIONS are not declared."**
   They are missing from *our* `AndroidManifest.xml`, but plugins merge them in:
   `camera_android_camerax` adds `CAMERA` and `RECORD_AUDIO`, and
   `firebase_messaging` and `flutter_local_notifications` add
   `POST_NOTIFICATIONS`. The final app already has them. **Consequence:**
   permission checks must read the **merged manifest of the built app**, never
   the source file. A test on the source file would have passed while being
   wrong.
2. **New: the camera and microphone prompts fire the moment the app first
   opens** (`loading.dart:45`, `requestCameraAndMicPermission()` in
   `initState`), before sign-up and before the friendly explanation dialog
   (`cam_mic_primer.dart`). On Android, a second "Don't allow" is permanent, so a
   cold prompt at launch can lose the patented feature for good. Fixed in
   Step 3.
3. **Wrong order: the closed test cannot start before the store paperwork.**
   Play blocks closed-testing releases until the listing, privacy policy, Data
   Safety form and content rating are complete, and closed releases are
   reviewed by Google. The policy risks (photos, Deceptive Behavior) therefore
   bite **at the closed test**, not at production. The paperwork is now
   Step 9, before the test.
4. **New: the closed test has to run on the production app, against the
   production backend.** The 12-testers rule is per app, so it has to be
   `com.reacti.app` (a staging-app test does not count). Staging also deletes
   chats older than 24 hours, which would sabotage genuine use. So the three
   additive backend changes must be **in production before the test**
   (Step 10), deployed in the normal release order.
5. **New: the invite web page only offers the App Store**
   (`invite.blade.php:239`; its own comment says "add it here when Android
   ships"). An Android friend who taps an invite is sent to Apple. That breaks
   the growth loop on Android. Fixed in Step 8.
6. **New: Android Firebase settings are hardcoded in Dart**
   (`firebase_options.dart`, `android` constant). A staging flavor needs an
   `androidStaging` entry (as iOS has `iosStaging`). `google-services.json`
   must also list both packages, or the Gradle Google Services task fails the
   staging build outright.
7. **New: the Android photo picker is opt-in in `image_picker`.**
   `ImagePickerAndroid.useAndroidPhotoPicker` defaults to `false`, so without it
   `pickMultipleMedia` opens the generic file chooser instead. Set it once at
   startup.
8. **Corrected: the policy date.** The first version said Google "began
   rejecting releases on 2026-09-24". That could not be verified. Google's own
   pages say compliance has been mandatory since January 2025 (extensions ended
   May 2025). Its guidance also says messaging apps that send photos are
   expected to use the photo picker, so **Decision D1 is now effectively
   decided by policy**, not preference.
9. **New: personal accounts must verify a physical Android phone** (Android
   10 or later) through the Play Console mobile app before publishing. The
   device kit is needed at account setup, not only for testing.
10. **Better: staging goes through Firebase App Distribution, not a second Play
    app.** It needs no Play account and no review, so Steps 1-8 are not blocked
    if account verification drags.
11. **Better: `assetlinks.json` lists two fingerprints** (the upload key and
    Play's signing key). Invite links then work for sideloaded *and* Play
    builds, and the "links broken until after the first upload" trap from the
    first version disappears.
12. **Confirmed: contacts leave the device.** `find_screen.dart:468` posts
    phone numbers to `findContacts`. Play's prominent-disclosure rule
    therefore applies, and the existing explanation text must say so.
13. **New: Android 15/16 behaviours that `targetSdk 36` switches on.**
    Edge-to-edge is forced (content can slide under the status and navigation
    bars). On large screens the portrait lock (`helpers_method.dart:79`) is
    ignored. Both are added to the parity sweep.
14. **New: adding flavors breaks plain `flutter run` on Android.** From Step 2
    on, `--flavor` is required, and `CLAUDE.md`'s run instructions and CI must
    be updated in the same PR.
15. **Kept from the first revision:** the screen-flash (PR #425) is
    manual-camera only, not part of the patent flow. The system picker keeps
    multi-select, caption and review, and only the inline grid is lost.

---

## Execution log and corrections found while building

Started 2026-09-29. Each step is a draft PR into `develop`, stacked in order.

| Step | PR | State |
|---|---|---|
| 1 Test harness | #457 | **Merged.** Gate passed, and proven able to fail by throwaway PRs #458 (a `throw` in `main()`, so the smoke went red) and #459 (an extra permission, so the diff went red). |
| 3 Permissions | #460 | Built; CI passing |
| 5 Front camera | #461 | Built; 18/18 local incl. patent harness |
| 6 Push | #462 | Built |
| 7 Photo picker | #463 | Built |
| 8 Invite page Play button (part 1) | #464 | Built; App Links (part 2) waits on Steps 2 and 4 |

Corrections to the plan above, learned from the code and the first builds:

* **Gallery permissions move from Step 3 to Step 7**, together with the
  picker switch, so the gallery never breaks in between.
* **Step 7 needs a new review screen.** On iOS the caption and the editor
  live *inside* the custom grid, not on a screen after it, so Android gets
  `PickedMediaReviewScreen` (filmstrip, editor, caption, send) after the
  system picker. Settings → Permissions also drops its Photos row on Android.
* **Q3 dropped:** iOS pushes use the *system default* sound (`receive.wav`
  plays only in-app), so Android's default sound is already parity.
* **Q13 moot:** the build shows `WRITE_EXTERNAL_STORAGE` merged with
  `maxSdkVersion 28`, so it is inert on modern Android.
* **Step 6 no longer depends on the prod backend release:** the manifest's
  FCM default channel and icon make background pushes correct on their own;
  the backend `AndroidConfig` adds high priority.
* **Data Safety, "Device or other IDs" is Yes regardless of `ANDROID_ID`:**
  Google's definition includes per-install IDs such as the FCM token (sent to
  our backend) and Sentry's random installation ID. Sentry does not read
  `ANDROID_ID`. The SDK check in Step 9 is no longer needed.
* **The invite page's Play button is off until `REACTI_PLAY_STORE_URL` is
  set**, so it can merge now and be switched on in Step 10.
* **Seen on the emulator:** the notification prompt also appears at first
  launch, before sign-up. Flagged, not changed (the iPhone does the same).
* **CI quirk:** PRs only get checks when based on `develop`; retargeting a PR
  does not trigger CI, but closing and reopening it does.

---

## Decisions (Achia)

| # | Decision | Recommendation |
|---|---|---|
| **D1** | Gallery on Android | **Android system Photo Picker.** Google's policy says messaging apps should use it. iOS keeps the current gallery. |
| **D2** | Personal or organisation Play account | **Organisation if Reacti is a registered company.** It skips the 12-testers-for-14-days rule and device verification, but needs a free D-U-N-S number, which can take days to weeks, so request it today. **Otherwise personal**, with your 12 testers. |
| **D3** | Device kit | **One Samsung and one Pixel**, at least one on Android 14 or later. One of them is also used for the account's device verification. |

---

## What already works

* **The Flutter app is the app.** Logic, state, networking and tests are
  platform-neutral Dart.
* **`android/` builds** a debug APK in CI, green throughout.
* **Camera, microphone and notification permissions are already in the final
  app** (merged from the plugins), and `loading.dart` already has an Android
  request path through `permission_handler`.
* **`MainActivity` is `FlutterFragmentActivity`**, which the app lock needs.
* **The adaptive launcher icon exists**, including the Android 13 monochrome
  layer.
* **The high-importance notification channel is created**, and
  `requestPermission()` already raises the Android 13 notification prompt.
* **`app_links` is a dependency**, and the backend already serves the Apple
  file per host (`routes/web.php`). `assetlinks.json` copies that pattern.
* **In-app delete-account exists** (`EndPoints.deleteAccount` →
  `/delete-profile`).
* **`targetSdk`/`compileSdk` are 36**, `minSdk` is 24.
* **Every analytics event is platform-neutral** and reports `platform`.

## Findings (verified 2026-09-29)

### Blockers

| # | Finding | Step |
|---|---|---|
| B1 | Release builds are **signed with the debug key** (`build.gradle.kts:38`). Play rejects them. | 4 |
| B5 | **No App Links filter, no `assetlinks.json`.** Invite links open a browser. | 8 |
| B6 | **No Play account.** A personal account also needs device verification and the 12-testers-for-14-days rule. | 0, 11 |
| B7 | **The invite page offers only the App Store.** | 8 |
| B8 | **No store paperwork.** Play blocks the closed test without it. | 9 |

### Patent flow

| # | Finding | Step |
|---|---|---|
| P1 | `recorder.dart:79-89` uses **`cameras.last` on Android** instead of matching the front lens. The reaction may film the wrong way. | 5 |
| P2 | **The camera and microphone are requested cold at first launch** (`loading.dart:45`), bypassing the primer. On Android a second denial is permanent. | 3 |
| P3 | **Deceptive Behavior policy.** Front-camera recording without a preview must be plainly disclosed in the listing and review notes. | 9 |
| P4 | Android cuts off the camera when an app goes to the background. **What happens if the recipient leaves mid-recording** has never been tested on Android. | 5 |

### Quality and parity

| # | Finding | Step |
|---|---|---|
| Q1 | The push payload has **no `AndroidConfig`**, so it never names `high_importance_channel`. | 6 |
| Q2 | The notification icon is the colour launcher icon, which Android draws as a **white blob**. | 6 |
| Q3 | The sound is a Flutter asset. Android channels need it in **`res/raw/`**. | 6 |
| Q4 | **No staging flavor**, and **no Android staging Firebase app** (`firebase_options.dart` and `google-services.json` know only `com.reacti.app`). | 2 |
| Q6 | **`WRITE_CONTACTS`** is declared but never used. | 3 |
| Q7 | The app badge only works on some launchers. That is expected, not a bug. | 12 |
| Q8 | **16 KB page size** for plugin native libraries is unverified. | 4 |
| Q9 | **Back navigation**, including predictive back, has never been tested. | 12 |
| Q10 | **Release-mode shrinking (R8)** has never run. | 1 |
| Q11 | The **manual-camera screen-flash** is only verified on iPhone. | 12 |
| Q12 | **Forced edge-to-edge** (Android 15 and later) and the **portrait lock being ignored on large screens** (Android 16). | 12 |
| Q13 | `video_compress` merges `WRITE_EXTERNAL_STORAGE` with no upper limit. It is harmless on Android 11 and later, but shows on the listing. | 3 |

### Store compliance

| # | Finding | Step |
|---|---|---|
| S1 | **Photo & Video Permissions policy.** Resolved by D1. | 3, 7 |
| S2 | **Data Safety form**, including whether PostHog or Sentry read `ANDROID_ID`. | 9 |
| S3 | **Privacy policy.** It is served from the database (`DynamicPage`), and its text must be checked against the Android data flows (Firebase push, Google Play). | 9 |
| S4 | **Account deletion web page.** Play requires one in addition to the in-app option. | 9 |
| S5 | **Contacts prominent disclosure**, because phone numbers are uploaded. | 9 |
| S6 | **App access.** Reviewers need a working login with a friend and content, so they can see the reaction flow. | 9 |

---

## How every step is tested

| Kind | What it proves | Where |
|---|---|---|
| **CI** | Unit, widget and backend tests, plus the **merged-permission check** | Every PR |
| **Emulator smoke** | The *release* build installs, launches and does not crash | Every PR, from Step 1 |
| **Play pre-launch report** | Crashes, 16 KB and accessibility on Google's real devices | Every Play upload, from Step 4 |
| **Device check** | The camera, notifications, links and feel, run from a written checklist | Device kit phones |

Rules for every step:

* One step per PR (or a small set), merged to `develop`, then an **Android
  staging build** is sent to the device kit through Firebase App Distribution.
* The gate result is written in the PR. A device check attaches a screenshot or
  recording.
* **When shared Dart code or the backend changes, iOS is re-checked**: the
  required checks, plus an iOS staging build for anything on the patent path.
* **Earlier checks keep running.** A later PR that breaks an earlier step turns
  CI red.

---

## Step 0 — Decisions, account, devices (Achia, starts today, parallel)

1. Settle D1-D3. For an organisation account, request the D-U-N-S number
   first.
2. Register the Play Console account ($25 one-time). Complete identity
   verification, and **device verification with a device kit phone** if the
   account is personal.
3. **Create the app `com.reacti.app`** to reserve the package name for good.
4. Collect the 12 testers' Google account emails into a Play tester list.
5. Enable **Firebase App Distribution** in the existing Firebase project, and
   add the device kit and team as testers.

**Gate:** the app exists in Play Console; the tester list has 12 or more
emails; a device kit phone is in hand with USB debugging on.
*Only Step 4b and later need the account. Steps 1-4a do not wait for it.*

---

## Step 1 — Test harness

* `flutter-ci.yml`: the `build-android` job builds a **release** APK. Until
  Step 4 it signs with the debug key when no upload key is present, so PRs need
  no secrets.
* **Emulator smoke job** (`reactivecircus/android-emulator-runner`): install
  the release APK, launch it, and fail on any `FATAL EXCEPTION` in logcat or if
  the process has died. Non-required at first; it becomes required after a week
  without flakes.
* **Merged-permission check:** dump the *built* APK's permissions
  (`aapt2 dump permissions`) and `diff` them against a checked-in
  `app/android/permissions.allowlist`. At this step the allowlist records
  today's state, and every later change to it is visible in review.

**Gate:**
- CI green: release build, smoke, permission diff.
- **Prove each check can fail.** On a throwaway branch: a `throw` in `main()`
  must turn the smoke job red, and adding a permission must turn the diff red.
- Any R8 release-only crash (Q10) is fixed here.

---

## Step 2 — Staging and production flavors

* `productFlavors`: `staging` (`applicationIdSuffix ".staging"`, "Reacti
  Staging", the amber icon) and `production`.
* Register `com.reacti.app.staging` in Firebase. Add it to
  `google-services.json`, and add an `androidStaging` entry to
  `firebase_options.dart`, selected by `ANALYTICS_ENV` exactly as `iosStaging`
  is.
* Build commands pass `--flavor` and the same `--dart-define`s as
  `ios-testflight.yml`. Update `CLAUDE.md`'s run instructions and every
  workflow that builds Android.
* A workflow sends each `develop` staging build to Firebase App Distribution.

**Gate:**
- CI: smoke launches **both** flavors on the same emulator. The permission
  diff runs per flavor.
- A unit test shows `DefaultFirebaseOptions` picks `androidStaging` when
  `ANALYTICS_ENV=staging` and `android` otherwise. The iOS selection test is
  unchanged.
- Device check: both apps install side by side from App Distribution. Staging
  signs in with `smoke-a@reacti.test`, and a push sent to it arrives, which
  proves the staging Firebase app is wired correctly.

---

## Step 3 — Permissions

* Remove `WRITE_CONTACTS`. Per D1, also remove `READ_MEDIA_IMAGES`,
  `READ_MEDIA_VIDEO` and `READ_EXTERNAL_STORAGE`. Strip `video_compress`'s
  `WRITE_EXTERNAL_STORAGE` with `tools:node="remove"` (Q13) once a grep confirms
  nothing writes to shared storage.
* Declare `android.hardware.camera` and `.camera.front` with
  `required="false"`, so camera-less tablets are not filtered out.
* **Stop the cold prompt (P2):** on Android, drop the launch-time
  `requestCameraAndMicPermission()` and let `CamMicPrimer.ensure` ask just
  before first use, as it was designed to. iOS behaviour is left as it is
  unless Achia decides otherwise, because it is the live app's behaviour.

**Gate:**
- CI: the permission allowlist shrinks to the final set. A widget test shows
  `Loading` asks for no permission on Android.
- Device check, **fresh install**: no prompt at launch. The primer, then the
  prompt, appear at the first Reacti open. Deny once, then twice: no crash, and
  the "enable in Settings" route works. The notification prompt appears on
  Android 13 or later.
- PostHog staging: `permission_result` events with `platform: android` and the
  right `denied`/`permanently_denied` values.

---

## Step 4 — Signing and the first Play upload

**4a (no account needed):** create the upload keystore and store it with
`gh secret set`. It is never displayed and never committed, and `key.properties`
and `*.jks` are gitignored in the same commit. The release config signs with
it. Pin `targetSdk 36` / `minSdk 24` literally. The staging flavor gets its own
upload key.

**4b (needs the account):** enrol in **Play App Signing**. Add
`android-release.yml` (manual trigger now, `v*` tags later) to upload a signed
**production** AAB to the **internal testing** track. The service-account key
goes in secrets only. `versionCode` must always increase: derive it from the run
number.

**Gate:**
- 4a: CI builds a release APK signed with the upload key, and `apksigner verify`
  confirms it is not the debug certificate.
- 4b: the build **installs from the Play internal track** on a device kit
  phone. The pre-launch report is read and every crash triaged. The bundle
  explorer shows **no 16 KB warning** (Q8); any offending plugin is upgraded,
  replaced or dropped before moving on. Both SHA-256 fingerprints (upload key
  and Play app signing key) are recorded in the PR for Step 8.

---

## Step 5 — The patented flow on Android

* `recorder.dart`: one rule for both platforms. Match
  `lensDirection == front`, fall back to the first camera, and record
  `camera_no_front` when there is no front lens.
* Keep the patent-flow harness (InboxScreen and GroupInboxScreen) green, per
  `CLAUDE.md`.

**Gate:**
- CI: unit tests with the **front camera in the middle** of the list and with
  **no front camera**. `cameras.last` fails both; the fix passes both. The
  harness is green.
- Device check on **both** device kit phones, 1:1 and in a group, in both
  directions with an iPhone: the reaction is the viewer's face, the right way
  up, with audio. Recordings are attached.
- **Interruption (P4):** press Home mid-recording. The app does not crash, does
  not upload a broken file, and the next Reacti records normally.
- **iOS regression:** the same loop on an iOS staging build.

---

## Step 6 — Push notifications

* Backend: add `AndroidConfig` to `Helper::buildPushMessage`
  (`channel_id: high_importance_channel`, high priority). This is additive and
  changes no response shape. It deploys to staging now and reaches production
  in Step 10.
* App: a white-silhouette `ic_notification` used by the local notifications
  and the FCM default-icon meta-data. Copy `receive.wav` into `res/raw/` for
  the channel.

**Gate:**
- CI: the backend test asserts the Android channel id and priority, and the
  APNs assertions are unchanged.
- Device check with the app in the **foreground, background and killed**: a
  heads-up banner, the silhouette icon, the Reacti sound, and a tap opens **the
  right chat**.
- iOS regression: an iPhone push still has sound and badge.

---

## Step 7 — Gallery (D1)

* Set `ImagePickerAndroid.useAndroidPhotoPicker = true` at startup (Android
  only).
* On Android, the gallery button calls `pickMultipleMedia` and hands the files
  to the existing review-and-caption screen. iOS keeps `whatsapp_asset_picker`.

**Gate:**
- CI: a widget test shows the Android path passes several picked files into
  review with the caption kept. The iOS path test is unchanged. The permission
  allowlist still has no `READ_MEDIA_*`.
- Device check: send 1, then 5 mixed photos and videos with one caption. The
  iPhone receives them all with the caption, and **no media permission prompt
  appears**. The profile and group photo pickers (which also use
  `image_picker`) now open the system picker too.

---

## Step 8 — The invite loop

* **App Links**, per flavor, with `autoVerify`: production claims only
  `reacti.io/i/*`, staging only `staging.reacti.io/i/*` (the iOS lesson from
  PRs #426/#427).
* **`assetlinks.json` per host** in `routes/web.php`, next to the Apple route,
  listing **both** fingerprints from Step 4.
* **Invite page:** show a Google Play button to Android browsers and the App
  Store button to everyone else, with the same funnel `step` tracking. Until
  the Play listing is public, the Android button links to the closed-test
  opt-in page.

**Gate:**
- CI: backend tests show each host returns its own package and fingerprints as
  JSON, and the invite page shows the Play button for an Android user agent and
  the App Store button for an iPhone.
- Google's Digital Asset Links tester passes for both hosts.
- Device check: `pm get-app-links` says **verified**. An invite link opens the
  staging app, not the browser and not the production app. Without the app
  installed, the link opens the page, the web demo (which uses the browser
  camera) works in Android Chrome, and the Play button goes to Play.

---

## Step 9 — Store paperwork (before the closed test)

Google blocks the closed test until all of this is done, and reviews what is
submitted.

* **Listing:** descriptions, icon, feature graphic, and at least two phone
  screenshots. The description says plainly that Reacti captures the
  recipient's reaction when they open a message (P3).
* **Content rating** questionnaire, matching the App Store's 16+, and the
  **target audience** declaration.
* **Data Safety**, mirroring `docs/analytics/app-store-privacy-declaration.md`.
  **Check the PostHog and Sentry Android SDK sources** for `ANDROID_ID` before
  answering "Device or other IDs".
* **Privacy policy:** check the database-served text covers the Android data
  flows.
* **Account deletion web page (S4):** a static page on reacti.io explaining the
  in-app route and giving an email for requests.
* **Contacts disclosure (S5):** the explanation shown before the contacts
  prompt must say phone numbers are sent to find friends. Change the text if it
  does not.
* **App access (S6):** a production review account that already has a friend
  and a Reacti, with the credentials in Play Console only. Review notes point to
  the camera primer and the consent flow.

**Gate:** Play Console's **"Set up your app" checklist is fully green**, the
deletion page loads signed out, and the contacts disclosure text is covered by
a widget test.

---

## Step 10 — Production backend release

The Android testers will use production. Ship the additive backend changes
(`AndroidConfig`, `assetlinks.json`, the invite page Play button, the deletion
page) through the **normal release order** (operator deploys). None changes an
API shape, so the live iOS app is unaffected.

**Gate:** in production, `reacti.io/.well-known/assetlinks.json` returns the
production fingerprints, the invite page shows the Play button to an Android
browser, and an iPhone on the App Store build still sends, reacts and gets
pushes (a smoke test with the prod-deploy smoke workflow).

---

## Step 11 — Closed test opens (14-day clock starts)

* Promote the production build from internal to the **closed** track and
  invite the 12 testers. Google reviews this release.
* Give testers a one-page "try these five things" sheet: sign up, add a friend,
  send a Reacti, open one, invite someone. That is the engagement Google checks.

**Gate:** 12 or more testers opted in and installed; each has completed the
five things; Sentry shows Android sessions with no new crash group. (With an
organisation account this is simply the beta, with no clock.)

Steps 12-13 run **during** the 14 days. Fixes ship as updates to the same
track, which does not reset the clock. **Testers must not opt out**, because
anyone who leaves before 14 days does not count.

---

## Step 12 — Parity sweep (one PR and one gate per row)

| # | Item | Gate |
|---|---|---|
| 12.1 | **Back navigation** (Q9) on the app lock, walkthrough, media viewer and chat | Widget tests per screen with custom pop handling. Device: back never skips the app lock or exits from a sub-screen. |
| 12.2 | **Edge-to-edge and large screens** (Q12) | Screenshots of the 8 main screens: nothing under the status or nav bar. On a tablet or resizable emulator, the layout survives landscape. |
| 12.3 | **Biometric app lock**, passcode fallback, `paused` vs `inactive` | Device: locks after backgrounding, not when the notification shade opens. The passcode works with no fingerprint enrolled. |
| 12.4 | **Badge** (Q7) | A unit test for silent failure. Device: a count on Samsung, no crash on Pixel. |
| 12.5 | **Manual camera screen-flash** (Q11) | Device: a front-camera flash photo in a dark room is lit, and the overlay clears if the capture fails. |
| 12.6 | **Image editor** layout (PR #443) | Device vs the iOS screenshots. |
| 12.7 | **Video** playback and compression | A 30-second video both ways with sound. `media_compressed` shows Android timings. |

**Gate:** every row passes, and no tester report rated "blocks use" is open.

---

## Step 13 — Analytics

* `country` comes from the locale and `$geoip_disable` stays set; `distinct_id`
  is still the salted hash.
* Add a `platform` breakdown to `scripts/analytics/growth_digest.py`, with a
  test, and segment the dashboards by platform.

**Gate:** CI covers the digest breakdown. In production PostHog, testers'
events carry `platform: android` and a country, and no device identifier.

---

## Step 14 — Clock completes, apply for production

Play's application asks about the test (recruitment, engagement, feedback),
the app, and **what changed because of testing**. Keep a running log from Step
11 so this is copy-paste.

**Gate:** Play confirms the requirement is met and production access is
granted.

---

## Step 15 — Production launch

Submit the production release.

**Gate:** on a clean phone, install from the **public** listing, sign up, and
do the full loop with an iPhone: send, react, push, invite link. `pm
get-app-links com.reacti.app` says verified. The invite page's Play button now
points at the public listing.

---

## Calendar

```
Step 0  ████████████████ (Achia, parallel; account can take days-weeks)
1-3     █████
4a       █
5-8        ████████      (staging via App Distribution; no account needed)
4b               █        <- needs the account
9                 ██      paperwork
10                  █     prod backend release
11                   █    clock starts
12-13                 ██████████████  (inside the 14 days)
14                                  █
15                                   ██  review
```

About **3-4 weeks** of engineering to Step 11, then 14 days, then a few days of
review: **5-6 weeks** in total, provided the account is verified by the time
Step 8 finishes. **The account is the thing to start today.**

---

## Risks, ranked

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Account verification or D-U-N-S is slow | Medium | Delays Step 4b onward | Start today; Steps 1-8 do not need it |
| Closed-test review rejects (Deceptive Behavior, photos) | Medium | Delays the clock | D1; Step 9 disclosure and review notes |
| Patent flow wrong camera or permanent denial | High on some devices | Core feature silently lost | Steps 3 and 5, two phone brands |
| Testers do not engage or opt out early | Medium | Production access refused | Step 11 sheet; ask testers to stay in |
| Release-only crash (R8) | Medium | Crash at launch | Step 1 smoke |
| Plugin fails 16 KB | Medium | Upload blocked | Step 4b bundle explorer |
| Prod backend release slips | Low | Testers get no push or links | Step 10 is additive and small |
| Device fragmentation | Certain | Small bugs | Step 12 and the pre-launch reports |

---

## Out of scope

* No Android-only features (widgets, Wear OS, tablet layouts, Auto).
* No backend change beyond the additive four: `AndroidConfig`,
  `assetlinks.json`, the invite page button and the deletion page. No response
  shapes change.
* No deferred deep link (Play Install Referrer). A new Android user enters the
  inviter code manually, exactly as on iOS. Add it only if the funnel shows
  drop-off there.
* No Play Billing, no other stores, no direct APK downloads.
* **iOS's cold launch-time camera prompt is flagged, not changed** (Step 3).
  That is Achia's call for the live app.
* The parked work (`friend_added`, demo copy, wireframe F5/F1) keeps its own
  schedule.

---

## Sources

Checked 2026-09-28/29:

- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Device verification requirements for new developer accounts](https://support.google.com/googleplay/android-developer/answer/14316361?hl=en)
- [Set up an open, closed, or internal test](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)
- [Details on Google Play's Photo and Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/14115180?hl=en)
- [Required actions to comply with the Photo & Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/15800983?hl=en)
- [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Understanding Google Play's app account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- [User Data policy: prominent disclosure and consent](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- [Deceptive Behavior policy](https://play.google.com/about/privacy-security-deception/deceptive-behavior/dishonest-behavior/)
- [Meet Google Play's target API level requirement](https://developer.android.com/google/play/requirements/target-sdk)
- [Prepare your apps for Google Play's 16 KB page size requirement](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html)
- [Photo picker](https://developer.android.com/training/data-storage/shared/photo-picker)

Code facts were verified against this repo and the plugin manifests in the pub
cache (`camera_android_camerax` 0.7.1+2, `firebase_messaging` 16.2.0,
`flutter_local_notifications` 21.0.0, `photo_manager` 3.9.0, `video_compress`
3.1.4, `image_picker_android` 0.8.13+16).
