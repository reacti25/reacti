# Plan — Android support and the Google Play Store

**Written 2026-09-28, revised 2026-09-29. Status: NOT STARTED.**
Achia has confirmed: there is **no Play Console account yet**, and **twelve
testers will be available**.

Reacti is iOS-only in production (1.6.0+19). An `android/` folder exists and
the app compiles to a debug APK in CI, but **nothing about it is shippable**:
release builds are signed with debug keys, the core patented feature cannot
work because the camera permission is not declared, push notifications cannot
arrive on any modern Android device, and invite links do not open the app.

This plan is split into **15 steps**. Each one ends in a **gate**: a
concrete check that proves the step works on its own. **A step is not done,
and the next one does not start, until its gate passes.** The point is that a
problem in step 3 shows up in step 3, not in week six when everything is
tested together.

---

## What changed in this revision (2026-09-29)

The first version was organised by *topic*. It is now organised by *order
of work*. Each step ends with a test. The review also changed several findings:

1. **The testing harness now comes first (Step 1).** The old plan had no way
   to test Android automatically: CI built a debug APK and never ran it. Now
   every step's gate has something to run.
2. **Signing, flavors and the first Play upload moved from Phase 6 to Steps
   2-4.** The old plan wired CI last, yet told us to upload early for the
   14-day clock. It could not do both. A release build also turns on code
   shrinking (R8), which can crash plugins that only a release build exercises.
   We want to find that on day two, not at submission.
3. **Corrected: the screen-flash is not part of the patent flow.** PR #425
   lights the subject for *manual* photos in `camera_capture_screen.dart`
   using a white overlay. The silent recorder does not use it. The old
   finding P2 is moved to the parity sweep.
4. **Corrected: the photo-picker cost was overstated.** The old plan said the
   Android system Photo Picker "costs the multi-select-with-caption flow". It
   does not. The system picker supports multi-select (`image_picker`'s
   `pickMultipleMedia`, already a dependency), and the caption and review step
   are Reacti's own screens *after* picking. What we actually lose is the
   inline WhatsApp-style grid. That makes the system picker far cheaper, so the
   recommendation flips to using it on Android (Decision D1).
5. **The photo-picker decision moved to the start.** It changes the manifest
   and the code, so it cannot wait for the store-listing phase.
6. **Added: a web page where users can request account deletion.** Play
   requires one in addition to in-app delete-account, and the old plan missed it.
7. **Added: prominent disclosure for contacts.** If contacts leave the device
   (contact matching), Play's User Data policy requires an in-app disclosure
   *before* the OS prompt. This needs checking against the code.
8. **Added: the Android 14 partial-access permission**
   (`READ_MEDIA_VISUAL_USER_SELECTED`) if we keep the custom picker.
9. **Added: a device kit.** Automated tests cannot prove the camera works, and
   nobody on the project currently has an Android device attached. At least one
   Samsung and one Pixel are needed from Step 5 on.
10. **The closed test opens earlier.** It opens once the core loop works (after
    Step 8), not after everything. Steps 9-13 then happen *during* the 14
    days, and testers get updates as they land. That saves about two weeks of
    calendar time.
11. **Added: an iOS regression check wherever shared Dart code changes.** The
    camera fix touches the recorder that the live iOS app uses.

---

## Decisions needed before Step 1 (Achia)

| # | Decision | Recommendation |
|---|---|---|
| **D1** | **Gallery on Android:** keep the custom WhatsApp-style picker and apply for Photo & Video permission, or use the Android system Photo Picker? | **System Photo Picker on Android.** Google started rejecting apps under this policy on 2026-09-24. Its guidance says apps that pick media occasionally (to share it, not to manage a library) should use the system picker. Multi-select, caption and review all survive (see change 4). iOS keeps the custom picker unchanged. |
| **D2** | **Personal or organisation Play account?** | **If Reacti is a registered company, open an organisation account.** It skips the 12-testers-for-14-days gate completely. It needs a free D-U-N-S number, which can take a few days to a few weeks, so request it today. **If there is no company, use a personal account** and the 12 testers. Either way, registering costs a one-time $25 and includes identity verification, so start now. |
| **D3** | **Device kit:** which physical Android phones do we test on? | At least **one Samsung** (the most common brand and the most unusual camera and launcher behaviour) and **one Pixel** (stock Android). One of them should be on Android 14 or later. |

---

## What already works

This is a finishing job, not a rewrite.

* **The Flutter app is the app.** All business logic, state, networking,
  theming and tests are platform-neutral Dart.
* **`android/` is scaffolded and builds** a debug APK in CI (`build-android`
  job in `flutter-ci.yml`), green throughout.
* **Android permission requests already exist in Dart.**
  `loading.dart` has a `_requestPermissionsAndroid()` path through
  `permission_handler`. It fails today only because the manifest does not
  declare the permissions it asks for.
* **`MainActivity` is already `FlutterFragmentActivity`**, which `local_auth`
  needs for the app lock.
* **The adaptive launcher icon exists**, including the Android 13 monochrome
  layer.
* **A high-importance notification channel is created** in
  `notification_services.dart`, and `firebase_messaging.requestPermission()`
  already raises the Android 13 notification prompt once the permission is
  declared.
* **`app_links` is already a dependency**, so invite links need a manifest
  entry and a server file on Android, not new Dart code.
* **The backend already serves the Apple file per host**
  (`routes/web.php`, `apple-app-site-association` and `.staging`). The Android
  `assetlinks.json` copies that pattern.
* **`targetSdk`/`compileSdk` resolve to 36** and `minSdk` to 24.
* **Every analytics event is platform-neutral**, and `platform: android` is
  already reported.

## Findings (verified in the code 2026-09-28/29)

### Blockers

| # | Finding | Step |
|---|---|---|
| B1 | `android/app/build.gradle.kts:38` signs release builds with the **debug keystore**. Play rejects the upload. | 4 |
| B2 | **`CAMERA` is not declared.** The patented capture and the in-app camera cannot run. | 3 |
| B3 | **`RECORD_AUDIO` is not declared**, but the recorder uses `enableAudio: true`. | 3 |
| B4 | **`POST_NOTIFICATIONS` is not declared.** No push on Android 13 and later. | 3 |
| B5 | **No App Links intent filter and no `assetlinks.json`.** Invite links open a browser. | 8 |
| B6 | **No account yet.** With a personal account, 12 testers must stay opted in for 14 days before production. | 0, 13 |

### Patent flow

| # | Finding | Step |
|---|---|---|
| P1 | `recorder.dart:79-89` picks **`cameras.last` on Android**. That is a convention, not a guarantee. On a phone that lists depth or wide-angle lenses, the "reaction" films the wrong way. iOS already matches `lensDirection == front`. | 5 |
| P3 | **Deceptive Behavior policy.** The app records the front camera with no preview, so the listing and the in-app disclosure must make the consent obvious. | 12 |

### Quality and parity

| # | Finding | Step |
|---|---|---|
| Q1 | `Helper::buildPushMessage` sets an APNs config but **no `AndroidConfig`**, so pushes never name `high_importance_channel`. They arrive without a banner and possibly without sound. | 6 |
| Q2 | The notification icon is the full-colour launcher icon, which Android draws as a **white blob**. | 6 |
| Q3 | The alert sound lives in Flutter `assets/`. Android channels can only play a sound from **`res/raw/`**. | 6 |
| Q4 | **No staging flavor.** Staging and production cannot be installed side by side. | 2 |
| Q5 | **Firebase has no Android staging app.** | 2 |
| Q6 | **`WRITE_CONTACTS` is declared** but nothing writes a contact. | 3 |
| Q7 | The app badge only works on some launchers (Samsung, Xiaomi), not on Pixel. That is expected, not a bug. | 10 |
| Q8 | **16 KB page size.** Several plugins ship native libraries. This must be verified. | 4 |
| Q9 | **Back navigation has never been tested** on the app lock, walkthrough, media viewer or chat. | 10 |
| Q10 | **Release-mode shrinking (R8)** has never run. Plugins that use reflection can crash only in release builds. | 1 |
| Q11 | **Screen-flash for manual front-camera photos** (PR #425) was only verified on iPhone. | 10 |

### Store compliance

| # | Finding | Step |
|---|---|---|
| S1 | **Photo & Video Permissions policy.** The custom gallery asks for `READ_MEDIA_IMAGES`/`VIDEO`, which is exactly what this policy targets. Settled by D1. | 7 |
| S2 | **Data Safety form**, including whether the PostHog or Sentry SDK reads `ANDROID_ID`. | 11 |
| S3 | The privacy policy URL must be on the listing. | 12 |
| S4 | **Account deletion web URL.** Play requires a web page for deletion requests as well as the in-app option. | 12 |
| S5 | **Prominent disclosure for contacts.** Needed if contacts are uploaded for matching; must be checked. | 12 |

---

## How every step is tested

Every step's gate is made of some of these four kinds of check. Each step says
which it uses.

| Kind | What it proves | Where it runs |
|---|---|---|
| **CI** | The code is right: unit tests, the manifest test, backend tests | Every PR, automatically |
| **Emulator smoke** | The *release* build installs, launches and does not crash | CI, from Step 1 |
| **Play pre-launch report** | Runs on Google's real devices: crashes, 16 KB, accessibility | After every Play upload, free |
| **Device check** | What automation cannot see: the camera, notifications, links, feel | A physical phone from the device kit, with a written checklist |

Rules that apply to every step:

* **One step per PR** (or a small set of PRs), merged to `develop`, followed
  by an **Android staging build** installed on the device kit, the same way iOS
  gets a TestFlight build per feature.
* **The gate is recorded** in the PR description. For a device check, a
  screenshot or screen recording is attached.
* **When shared Dart code changes**, the iOS required checks stay green *and*
  an iOS staging build is sanity-checked. Android work must not break the live
  platform.
* **The earlier gates keep running.** Everything automated is re-run on every
  later PR, so a regression in an earlier step turns CI red right away.

---

## Step 0 — Accounts and devices (Achia, starts today, runs in parallel)

No code. Nothing else is blocked by it until Step 4, so it can run alongside
Steps 1-3.

1. Settle D2. If organisation, request the D-U-N-S number first.
2. Register the Play Console account and complete identity verification.
3. **Create the app `com.reacti.app`** in Play Console. This reserves the
   package name, which can never be changed.
4. Also register **`com.reacti.app.staging`** as a second app, so the staging
   build has its own internal track (the same arrangement as TestFlight).
5. Collect the 12 testers' **Google account emails** and put them in a Play
   tester list. Remember that they need Android phones.
6. Get the device kit (D3) and turn on USB debugging.

**Gate:** Play Console shows both apps as created, the tester list has 12 or
more emails, and at least one device kit phone is in hand.

---

## Step 1 — Test harness: a release build that launches in CI

**Why first:** every later gate needs a way to run the Android app. Today CI
only compiles a debug APK and never runs it.

* In `flutter-ci.yml`, change `build-android` to build a **release** build
  (`flutter build apk --release`). Until Step 4 it falls back to the debug key
  when no upload key is present, so PRs stay buildable without secrets.
* Add an **emulator smoke job** (`reactivecircus/android-emulator-runner`):
  install the release APK, launch it, wait for the first screen, and **fail on
  any `FATAL EXCEPTION` in logcat** or if the process has died. It is not a
  required check at first, because emulators can be flaky; it becomes one once
  it has proven stable for a week.
* Add **`app/test/android_manifest_test.dart`**: a plain Dart test that parses
  `AndroidManifest.xml` and asserts the permissions we must have and must *not*
  have. It starts out asserting today's state, and each later step tightens it.

**Gate:**
- CI: the release build and emulator smoke are green on a PR.
- **Prove the harness can fail:** on a throwaway branch, add a `throw` in
  `main()` and confirm the smoke job goes **red**. A test that cannot fail
  proves nothing.
- Any R8 crash found here is fixed in this step (Q10).

---

## Step 2 — Staging and production flavors, side by side

* Add `productFlavors`: `staging` (`applicationIdSuffix = ".staging"`, app
  name "Reacti Staging", the amber icon) and `production`.
* Register `com.reacti.app.staging` in Firebase and put a
  `google-services.json` in each flavor's folder (`src/staging/`,
  `src/production/`).
* Each flavor's build passes its own `--dart-define`s exactly like
  `ios-testflight.yml`: staging API URL, `ANALYTICS_ENV=staging`, and so on.

**Gate:**
- CI: the smoke job builds, installs and launches **both** flavors on the same
  emulator, and both run at once.
- Manifest test: each flavor has the right package name.
- Device check: both apps show on the home screen with different icons and
  names. Signing into staging with `smoke-a@reacti.test` works, which shows it
  talks to the staging API.

---

## Step 3 — Permissions and manifest cleanup

* Add `CAMERA`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`.
* Remove `WRITE_CONTACTS` (grep confirms no write path; re-check first).
* Declare the camera features as `android:required="false"`, so tablets without
  a front camera are not filtered out of the store.
* Gallery permissions follow **D1**. With the system Photo Picker, remove
  `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` and `READ_EXTERNAL_STORAGE`. The
  gallery code itself changes in Step 7. With the custom picker, add
  `READ_MEDIA_VISUAL_USER_SELECTED` for Android 14 partial access instead.

**Gate:**
- CI: `android_manifest_test.dart` now asserts the full final permission set,
  **including what must be absent**.
- Device check on a **fresh install**: the camera and microphone prompts appear
  at the point `loading.dart` asks, and the notification prompt appears on
  Android 13 or later. Deny each one once, then twice ("don't ask again"), and
  confirm the app does not crash and shows the Open Settings route. Android
  treats a second denial as permanent, which differs from iOS.
- `permission_result` events arrive in PostHog staging with `platform: android`
  and the right `denied`/`permanently_denied` values.

---

## Step 4 — Release signing and the first Play upload

This step starts the Play-side machinery early, while it is cheap to fix.

* Create the upload keystore. Store it as a GitHub secret (base64) together
  with its passwords using `gh secret set`. Never display it, and never commit
  it. `android/key.properties` and `*.jks` are gitignored **in the same
  commit**.
* **Enrol in Play App Signing.** Google holds the app signing key. We hold only
  the upload key, which can be reset if lost.
* Pin `targetSdk = 36` and `minSdk = 24` literally in `build.gradle.kts`,
  with a comment naming Play's requirement.
* Add `android-internal.yml`: `workflow_dispatch` builds a signed staging AAB
  and uploads it to the **internal testing** track. `versionCode` comes from
  the run number and `versionName` from `pubspec.yaml`, as on iOS.
* The Play service-account key goes in a GitHub secret only.

**Gate:**
- The workflow uploads without errors.
- Device check: the build **installs from the Play internal track** (not
  sideloaded) on a device kit phone and launches.
- The **pre-launch report** is read and every crash is triaged. The Play
  bundle explorer shows **no 16 KB page-size warning** (Q8). If one appears,
  the offending plugin is upgraded, replaced or dropped, in that order,
  *before* the next step.
- Copy the **app signing SHA-256** from Play Console into the PR. Step 8 needs
  it.

---

## Step 5 — The patented flow on Android

This is the step that must not be rushed.

* In `recorder.dart`, replace the platform branch with one rule for both
  platforms: pick the camera where `lensDirection == front`, falling back to
  the first camera, and record `camera_no_front` as the failure reason when no
  front lens exists.
* Per `CLAUDE.md`, this changes the recording trigger's inputs, so the
  patent-flow harness (InboxScreen and GroupInboxScreen) must stay green.

**Gate:**
- CI: a new unit test with a fake camera list where the **front camera is in
  the middle** of the list, and one with **no front camera**. `cameras.last`
  fails both, and the fix passes both. The patent-flow harness is green.
- Device check on **both** device kit phones: an iPhone sends a photo, the
  Android phone opens it, and the reaction that comes back is **the Android
  user's face, the right way up, with audio**. Then the same in reverse, and in
  a group. Attach the screen recordings to the PR.
- **iOS regression:** the same loop on an iOS staging build still works,
  because the recorder is shared code.

---

## Step 6 — Push notifications

* **Backend:** add `AndroidConfig` to `Helper::buildPushMessage` with
  `notification.channel_id = 'high_importance_channel'` and high priority.
  This is additive and changes no response shape, so it is safe for the old
  app. It deploys to staging now and rides the next normal release to prod,
  which must happen **before the Android launch**.
* **App:** a white-silhouette `res/drawable/ic_notification.xml` used by
  `AndroidNotificationDetails` and the FCM default-icon meta-data. Copy
  `receive.wav` into `res/raw/` and point the channel at it.

**Gate:**
- CI: the backend test for `buildPushMessage` asserts the Android channel id
  and priority. The existing APNs assertions still pass.
- Device check, for each state **foreground / background / app killed**: send
  from the iPhone, and confirm a heads-up banner, a silhouette icon (not a
  blob), the Reacti sound, and that tapping it opens **the right
  conversation**.
- iOS regression: a push to an iPhone still arrives with sound and badge.

---

## Step 7 — Gallery and media sending (per D1)

With the recommended system Photo Picker:

* On Android, open the system picker (`image_picker.pickMultipleMedia`) where
  the custom `whatsapp_asset_picker.dart` opens today. Pass the result into the
  existing review-and-caption screen. iOS is unchanged.

**Gate:**
- CI: a widget test showing the Android path hands several picked files to the
  review screen with the caption kept. The iOS path test is unchanged.
- Device check: pick 1, then 5 mixed photos and videos, add one caption, and
  send. The iPhone receives them all with the caption. No media permission
  prompt appears at all, which is the point of this route.
- Manifest test: no `READ_MEDIA_*` permissions (already enforced since Step 3).

---

## Step 8 — Invite links (App Links)

* Intent filters with `android:autoVerify="true"`, **per flavor**: production
  claims only `reacti.io/i/*`, staging claims only `staging.reacti.io/i/*`.
  This is the iOS lesson from PRs #426/#427, where the staging app stole
  production links.
* The backend serves `/.well-known/assetlinks.json` **per host**, copying the
  existing AASA route in `routes/web.php`. It uses the SHA-256 from Step 4.

**Gate:**
- CI: a backend feature test shows each host serves its own package name and
  fingerprint with `Content-Type: application/json`. The manifest test shows
  each flavor claims only its own host.
- Google's Digital Asset Links tester passes for both hosts.
- Device check: `adb shell pm get-app-links com.reacti.app.staging` reports
  **verified**. An invite link from staging opens the staging app into the
  invite, and does not open the browser or the production app.

---

## Step 9 — Open the closed test (the 14-day clock starts)

The core loop now works end to end: install, sign up, send, react, get
notified, invite a friend. That is enough for testers to use the app for real,
which Google checks.

* Add `android-release.yml`: a `v*`-tag-driven production AAB to the
  **closed** track, mirroring `ios-release.yml`.
* Upload the production build to the closed track and invite the 12 testers.
* With an organisation account (D2), this step is simply the beta, with no
  clock attached.

**Gate:**
- **12 or more testers have opted in** (shown in Play Console) and each has
  installed the app.
- Every tester can do the core loop. Give them a one-page "try these five
  things" sheet, which also produces genuine engagement.
- Sentry shows Android sessions arriving with no new crash group.

Steps 10-13 run **during** the 14 days. Every fix ships to the testers as an
update to the same closed track, and that does not reset the clock.

---

## Step 10 — Parity sweep (small steps, each with its own gate)

Each item is its own PR with its own gate. Do not batch them.

| # | Item | Gate |
|---|---|---|
| 10.1 | **Back navigation** (Q9): hardware back and predictive back on the app lock, walkthrough, media viewer and chat | A widget test per screen that has custom pop handling. On the device: back never exits the app from a sub-screen and never bypasses the app lock. |
| 10.2 | **Biometric app lock**: `local_auth`, the passcode fallback, and `paused` vs `inactive` | Device check: lock fires after backgrounding, **not** when the notification shade opens. The passcode works with no fingerprint enrolled. |
| 10.3 | **App badge** (Q7) | A unit test shows `AppBadge` failing silently when unsupported. Device check: a count on Samsung, no crash on Pixel. |
| 10.4 | **Manual camera and screen-flash** (Q11) | Device check: a front-camera photo with flash in a dark room is lit, and the overlay goes away when the capture fails. |
| 10.5 | **Image editor** (PR #443 layout) | Device check against the iOS screenshots: tools at the top, confirm button at the bottom right. |
| 10.6 | **Video playback and compression** | Device check: send a 30-second video both ways, it plays with sound, and `media_compressed` shows Android timings in PostHog. |
| 10.7 | **Layout and dark mode** on a 16:9 and a 20:9 phone | Screenshots of the 8 main screens, compared with iOS. |

**Gate for the step:** all seven rows are done, and the testers' reports
contain no open Android-only bug rated "blocks use".

---

## Step 11 — Analytics and Data Safety

* Verify `country` comes from the device locale on Android, and that
  `$geoip_disable` stays set (there is a test).
* Verify `distinct_id` is still the salted hash.
* **Check in the SDK source** whether PostHog's or Sentry's Android SDK reads
  `ANDROID_ID`. Do not guess.
* Add a `platform` breakdown to `scripts/analytics/growth_digest.py`, with a
  test, and segment the dashboards by platform.
* Fill in the Data Safety form from `docs/analytics/app-store-privacy-declaration.md`.

**Gate:**
- CI: the digest test covers the platform breakdown.
- PostHog staging: an Android event carries `platform: android`, a `country`,
  and no device identifier.
- Data Safety: every row matches the iOS declaration, and "Device or other
  IDs" is answered from the SDK check.

---

## Step 12 — Store listing and policy declarations

* **Account deletion web URL (S4):** a simple page on reacti.io that explains
  how to delete your account in the app and gives an email for requests.
* **Contacts disclosure (S5):** check whether contacts are uploaded. If they
  are, confirm an in-app explanation appears *before* the OS prompt, as the
  iOS camera primer does.
* **Deceptive Behavior (P3):** the listing says plainly that Reacti captures
  the recipient's reaction when they open a message. The review notes point to
  the consent flow and the camera primer.
* The listing: screenshots, feature graphic, descriptions, privacy policy URL,
  and the content-rating questionnaire answered to match the App Store's 16+.

**Gate:** Play Console → **App content** shows every item complete with no
warnings, and the account deletion URL loads in a signed-out browser.

---

## Step 13 — The 14 days finish

**Gate:** Play Console confirms the testing requirement is met: 12 or more
testers opted in for 14 continuous days. With an organisation account there is
no clock, and this step is a readiness check only. Sentry's Android crash-free
rate matches iOS.

---

## Step 14 — Production

1. Confirm the **production backend** has the Step 6 `AndroidConfig` and the
   Step 8 `assetlinks.json`. Both are additive, and the operator deploys them
   in the normal release order.
2. Apply for production access and submit. Expect a review of a few days.

**Gate:** on a clean phone that has never installed Reacti, install from the
**public** Play listing, sign up, and do the full loop with an iPhone: send,
react, push, invite link. Production App Links verify with
`pm get-app-links com.reacti.app`.

---

## Order and calendar

```
Step 0  ████████████ (Achia, parallel)
Step 1  ██
Step 2    ██
Step 3      █
Step 4       ██          <- needs the account from Step 0
Step 5         ███       <- needs the device kit
Step 6            ██
Step 7              ██
Step 8                ██
Step 9                  █   14-day clock starts
Steps 10-12              ████████████  (during the clock)
Step 13                              █
Step 14                               ██  review
```

About **3-4 weeks of engineering** to Step 9, then **14 days** of closed
testing with Steps 10-12 inside them, then a few days of review: roughly **5-6
weeks** from start to a live listing. An organisation account removes the
14-day wait, but the D-U-N-S number can take as long as the wait it saves, so
start that request today if it applies.

---

## Risks, ranked

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Photo & Video policy rejection (S1) | High if we keep the custom picker | Blocks release | D1: system picker on Android (Step 7) |
| The 14-day tester clock (B6) | Certain on a personal account | 2+ weeks | D2; open the closed test at Step 9, not at the end |
| Patent flow picks the wrong camera (P1) | High on some devices | Core feature silently broken | Step 5, tested on two brands of phone |
| Release-only crash from R8 (Q10) | Medium | App crashes at launch | Found in Step 1 by the emulator smoke |
| Plugin fails 16 KB (Q8) | Medium | Blocks upload | Found in Step 4 by the bundle explorer |
| Deceptive Behavior review (P3) | Medium | Blocks release, can appeal | Step 12 listing copy and review notes |
| Testers do not really use it | Medium | Google refuses production access | Step 9 "try these five things" sheet |
| Device fragmentation | Certain | Many small bugs | Step 10 plus the pre-launch report on every upload |

---

## What this plan deliberately does not do

* **No Android-only features.** Parity with iOS only: no widgets, Wear OS,
  tablet layouts or Android Auto.
* **No backend changes beyond two additive ones**: `AndroidConfig` and
  `assetlinks.json` (plus the static deletion page). No response shapes change,
  so there is no old-app risk.
* **No Play Billing**, since there are no payments.
* **No other stores** (F-Droid, Amazon, Huawei) and no direct APK downloads.
* **The parked work stays parked**: the `friend_added` fix, the demo copy and
  wireframe F5/F1 ship on their own schedule.

---

## Sources

Checked 2026-09-28:

- [Meet Google Play's target API level requirement](https://developer.android.com/google/play/requirements/target-sdk)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Details on Google Play's Photo and Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/14115180?hl=en)
- [Required actions to comply with the Photo & Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/15800983?hl=en)
- [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Understanding Google Play's app account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- [User Data policy: prominent disclosure and consent](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- [Deceptive Behavior policy](https://play.google.com/about/privacy-security-deception/deceptive-behavior/dishonest-behavior/)
- [Prepare your apps for Google Play's 16 KB page size requirement](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html)
- [Grant partial access to photos and videos](https://developer.android.com/about/versions/14/changes/partial-photo-video-access)
- [Photo picker](https://developer.android.com/training/data-storage/shared/photo-picker)
