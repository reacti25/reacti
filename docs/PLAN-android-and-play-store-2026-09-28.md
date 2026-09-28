# Plan — Android support and the Google Play Store

**Written 2026-09-28. Status: NOT STARTED, awaiting Achia's go-ahead.**

Reacti is iOS-only in production (1.6.0+19). An `android/` folder exists and
the app compiles to a debug APK in CI, but **nothing about it is shippable**:
release builds are signed with debug keys, the core patented feature cannot
work because the camera permission is not declared, push notifications cannot
arrive on any modern Android device, and invite links do not open the app.

This plan covers everything needed to change that, in the order it has to
happen.

> **Read this first if you read nothing else.** The single longest pole is not
> code. If the Play Console account is a *personal* account, Google requires a
> closed test with **12 testers opted in continuously for 14 days** before it
> will grant production access, and since 2026 it also checks those testers
> genuinely used the app. That clock cannot be shortened and cannot be started
> until an installable build exists. Everything else in this plan can be worked
> around; that cannot. See **Phase 0**.

---

## Contents

1. [What already works](#what-already-works)
2. [What is broken or missing](#what-is-broken-or-missing) — the findings
3. [Phase 0 — Decisions and the 14-day clock](#phase-0)
4. [Phase 1 — Make it installable](#phase-1)
5. [Phase 2 — The patented flow on Android](#phase-2)
6. [Phase 3 — Push, deep links, and the invite loop](#phase-3)
7. [Phase 4 — Parity sweep](#phase-4)
8. [Phase 5 — Analytics and Data Safety](#phase-5)
9. [Phase 6 — CI, signing, and the release pipeline](#phase-6)
10. [Phase 7 — Store listing and policy declarations](#phase-7)
11. [Phase 8 — Closed test, then production](#phase-8)
12. [Risks, ranked](#risks-ranked)
13. [What this plan deliberately does not do](#out-of-scope)
14. [Sources](#sources)

---

## What already works

Worth stating, because it means this is a finishing job rather than a rewrite.

* **The Flutter app is the app.** All business logic, state, networking,
  theming and tests are platform-neutral Dart. The backend needs no Android
  work at all beyond one static file (Phase 3).
* **`android/` is scaffolded and builds.** `flutter build apk --debug` runs in
  CI on every PR, and it has been green throughout.
* **`MainActivity` is already `FlutterFragmentActivity`**, which `local_auth`
  requires for the app-lock biometric prompt. Someone hit that already.
* **The adaptive launcher icon exists**, including the `monochrome` layer for
  Android 13 themed icons. Better than many shipped apps.
* **A high-importance notification channel is created** in
  `notification_services.dart`.
* **`targetSdk` and `compileSdk` resolve to 36** through the Flutter Gradle
  plugin, which meets Play's August 2026 requirement, and `minSdk` is 24.
* **Every analytics event is platform-neutral**, and `analytics_service.dart`
  already reports `platform: android`.

## What is broken or missing

Findings from reading the code on 2026-09-28. Each one is addressed by a phase
below; the phase is named in the right-hand column.

### Blockers — the app cannot ship at all

| # | Finding | Phase |
|---|---|---|
| B1 | `android/app/build.gradle.kts` signs **release builds with the debug keystore** (`signingConfig = signingConfigs.getByName("debug")`, with the generated TODO still in place). Play rejects debug-signed uploads outright. | 1 |
| B2 | **`CAMERA` is not declared** in `AndroidManifest.xml`. The patented silent reaction capture cannot run. Nor can the in-app camera. | 1 |
| B3 | **`RECORD_AUDIO` is not declared.** The recorder calls `CameraController(..., enableAudio: true)`, which throws without it. | 1 |
| B4 | **`POST_NOTIFICATIONS` is not declared.** On Android 13+ (API 33, most of the install base) push is silently never delivered. | 1 |
| B5 | **No `App Links` intent filter and no `assetlinks.json`.** Invite links open a browser, never the app. The iOS side of this took two PRs (#426, #427) to get right. | 3 |
| B6 | **The Play Console closed-testing gate** (12 testers × 14 continuous days) if the account is personal. | 0 |

### Patent-flow risks — the core feature may silently misbehave

| # | Finding | Phase |
|---|---|---|
| P1 | `recorder.dart` picks the camera with **`cameras.last` on Android** — a convention, not a guarantee. On devices that enumerate depth sensors, wide-angle or external cameras, this is the wrong lens, and the "reaction" is a picture of a wall. On iOS the same code correctly matches `lensDirection == front`. **This is a correctness bug in the patented feature.** | 2 |
| P2 | The **screen-flash front-camera lighting** (PR #425) was built and verified on iOS only. Android's camera stack and brightness API behave differently. | 2 |
| P3 | Google Play's **Deceptive Behavior policy** is unusually relevant here: an app that records the front camera without a preview is exactly the shape of thing that policy exists to catch. Reacti is legitimate and consensual, but the store listing, the in-app disclosure and the Data Safety form have to make that obvious to a reviewer who has thirty seconds. | 7 |

### Quality and parity — it would ship, and be worse than the iPhone app

| # | Finding | Phase |
|---|---|---|
| Q1 | The FCM payload built in `Helper::buildPushMessage` sets an APNs config and default sounds but **no `AndroidConfig`, so no `channel_id`**. The app creates `high_importance_channel` and then never tells FCM to use it, so pushes land on the default channel: no heads-up, possibly silent. | 3 |
| Q2 | The notification icon is `@mipmap/ic_launcher`. Android renders status-bar icons as a **silhouette**, so a full-colour launcher icon becomes a **white blob**. Needs a dedicated monochrome drawable. | 3 |
| Q3 | The custom alert sounds live in `assets/sounds/` (Flutter assets). Android notification channels can only use a sound from **`res/raw/`**. | 3 |
| Q4 | **No `staging` product flavor.** iOS has a whole second app (`com.reacti.app.staging`, amber icon) that the entire staging/TestFlight workflow depends on. Android has one build type and no way to install staging alongside production. | 6 |
| Q5 | **Firebase has no Android staging app.** `google-services.json` registers only `com.reacti.app`. | 6 |
| Q6 | `WRITE_CONTACTS` is declared but nothing in the app writes a contact. Play treats unnecessary permissions as a policy problem, and it is a needless scary line on the store listing. | 1 |
| Q7 | `app_badge_plus` works on iOS universally; on Android it depends on the **launcher** (Samsung and Xiaomi yes, Pixel largely no). The badge feature will simply not appear for many users, and that is not a bug to chase. | 4 |
| Q8 | The 16 KB page-size requirement (mandatory since 2025-11-01 for native code). Flutter itself complies and the NDK is pinned to 29.x, but the app carries **many plugins with native libraries** (`video_compress`, `flutter_image_compress`, `photo_manager`, `camera`, `pro_image_editor`, `audioplayers`, `sentry_flutter`, `posthog_flutter`). This needs verifying, not assuming. | 4 |
| Q9 | Back-gesture, hardware back button, and predictive back (Android 15+) have **never been exercised**. Flutter apps commonly get this wrong on screens with custom pop handling, and this app has an app-lock gate, a showcase walkthrough, and a media viewer, all of which intercept navigation. | 4 |

### Store compliance — will get the submission rejected

| # | Finding | Phase |
|---|---|---|
| S1 | **Photo & Video Permissions policy.** The app requests `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` for its custom WhatsApp-style gallery (`wechat_assets_picker` / `photo_manager`). Google now requires a **Play Console declaration form** justifying why the system Photo Picker is insufficient, and **began rejecting production releases under this policy on 2026-09-24** — four days before this plan was written. This is the highest-probability rejection. | 7 |
| S2 | **Data Safety form** — the Play equivalent of the App Privacy declaration just completed for iOS. Same facts, different questionnaire, and it has its own trap: third-party SDK collection must be declared as yours, and `Settings.Secure.ANDROID_ID` (if PostHog or Sentry read it) counts as a Device ID. | 5 |
| S3 | The privacy policy already updated for 1.6.0 covers analytics, but must be reachable from the Play listing. | 7 |

---

## Phase 0 — Decisions and the 14-day clock

**Owner: Achia. Blocking. Do this before any code is written.**

Nothing here is engineering, and everything downstream waits on it.

### 0.1 — Answer three questions

1. **Is the Google Play Console account a personal account or an organisation
   account, and when was it created?** Organisation accounts registered to a
   legal business entity are exempt from the closed-testing requirement.
   Personal accounts created on or after 2023-11-13 are not. This single answer
   decides whether the timeline is roughly three weeks or roughly six.
2. **Is there a Play Console account at all yet?** If not, registration
   (including identity verification) should start today; it is not instant.
3. **Do we have twelve real people** who will install a test build and use it
   for a fortnight? They must be genuine — Google now checks that testers
   actually used the app. Reacti's existing TestFlight testers are the obvious
   pool, but they need Android devices.

### 0.2 — Reserve the package name

`com.reacti.app` matches the iOS bundle id and the existing
`google-services.json`. Create the app in Play Console early to claim it. A
package name can never be changed or reused once published.

### 0.3 — Decide the launch scope

**Recommendation: ship full parity, not a cut-down first version.** The app's
value is one loop (send media → they open it → their face comes back), and
every part of that loop crosses a feature this plan touches. There is no
coherent smaller thing to ship.

---

## Phase 1 — Make it installable

**Goal: a signed release build that installs on a real device and does not
crash on the core path.** Roughly one to two days of work.

### 1.1 — Permissions (B2, B3, B4, Q6)

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Remove `WRITE_CONTACTS` (Q6) unless a write path is found; a grep says there
is none.

Declare the camera as **not required**, so the app is not hidden from tablets
without a front camera — Reacti degrades gracefully when capture fails, and
that is already tested:

```xml
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.front" android:required="false" />
```

**Test:** extend `permission_analytics_test.dart` — the `permission_result`
event already distinguishes `permanently_denied` from `denied`, and Android's
"Don't allow" twice behaves differently from iOS's once-only prompt. This is
exactly the instrumentation built in PR #448, and Android is where it earns
its keep.

### 1.2 — Release signing (B1)

Create an upload keystore, store it as GitHub secrets (base64 of the `.jks`
plus the passwords), and wire a `release` signing config that reads from
`key.properties` generated at build time.

**Use Play App Signing.** Google holds the app signing key; we hold only the
upload key, which can be reset if lost. Losing a self-managed app signing key
means never being able to update the app again.

> **Secrets rule, unchanged:** the keystore and its passwords go in via
> `gh secret set` from the workspace and are never displayed, never pasted into
> chat, and never committed. `android/key.properties` and `*.jks` go into
> `.gitignore` in the same commit that introduces them.

### 1.3 — Pin the SDK levels explicitly

`targetSdk` currently resolves to 36 through the Flutter plugin default. That
is correct today and silently wrong the moment Flutter is downgraded. Pin
`targetSdk = 36` and `minSdk = 24` literally, with a comment naming Play's
2026-08-31 requirement.

### 1.4 — Verify it runs

Build a release APK, install on a physical device, and walk the core loop:
sign up, add a friend, send a photo, open one, confirm a reaction comes back.

**Expect failures here.** This is the first time this code has ever run as a
release build on Android. Budget for the unknown.

---

## Phase 2 — The patented flow on Android

**Goal: the north-star feature is correct, not merely present.** This is the
phase that must not be rushed.

### 2.1 — Fix the camera selection (P1)

```dart
// Today:
camera = cameras.last;   // Android: a convention, not the front camera
```

Replace with the same `lensDirection == CameraLensDirection.front` match used
on iOS, falling back to `cameras.last` only if no front lens is reported. The
platform branch then disappears entirely, which is the right shape: there was
never a reason for the two platforms to choose differently.

**Test:** a unit test over a fake camera list that puts the front camera in
the middle, and one where no front camera exists. `cameras.last` passes the
naive test and fails both of these, which is why it survived this long.

### 2.2 — Verify the screen-flash (P2)

PR #425 lights the subject by whitening the screen, since the front lens has
no lamp. Verify the brightness change actually takes effect on Android and is
restored afterwards, including when the recording fails mid-way.

### 2.3 — Run the patent harness on Android

The existing end-to-end harness (InboxScreen and GroupInboxScreen) is
platform-neutral Flutter test code and should pass unchanged. That it passes
proves the *wiring*, not the camera. The device walkthrough in 2.1 proves the
camera.

**This phase ends with a recorded device test**, not a green CI run: open a
Reacti on a physical Android phone and confirm the reaction that comes back is
the sender's face, correctly oriented, with audio.

> Per `CLAUDE.md`, any change to the recording trigger, the blur transition,
> the reaction upload path or `mark-viewed` needs a regression test that
> exercises the full loop. 2.1 changes the recording trigger.

---

## Phase 3 — Push, deep links, and the invite loop

**Goal: the two loops that bring people back work on Android.**

### 3.1 — App Links (B5)

Add the intent filter to `MainActivity` for `https://reacti.io/i/*` and
`https://staging.reacti.io/i/*`, with `android:autoVerify="true"`.

Serve `/.well-known/assetlinks.json` from the backend, alongside the existing
`apple-app-site-association`. It needs the **SHA-256 fingerprint of the app
signing certificate** — which, under Play App Signing, is Google's key, and is
only available from Play Console *after* the first upload. So:

1. Upload the first build to the closed track (Phase 8).
2. Copy the SHA-256 from Play Console → Setup → App signing.
3. Publish `assetlinks.json`.
4. Verify with Google's Digital Asset Links tester.

**This ordering is not optional and is easy to get wrong.** Budget for App
Links being broken during the first days of closed testing.

> Note the iOS lesson recorded in PR #426/#427: both apps claimed both hosts,
> and the staging app stole production links. The Android equivalent is the
> same mistake with `autoVerify`, so the staging flavor (Q4) must declare only
> the staging host.

### 3.2 — Notification channel in the payload (Q1)

Add an `AndroidConfig` to `Helper::buildPushMessage` carrying
`notification.channel_id = 'high_importance_channel'`, and a `priority`.
Without it every Android push lands on the default channel.

This is a **backend** change, and the first one in this plan. It is additive
and does not change any response shape, so it carries no old-app risk —
`buildPushMessage` already has a test, which is the right place to pin it.

### 3.3 — Notification icon and sound (Q2, Q3)

Add a white-silhouette `res/drawable/ic_notification.xml` and reference it from
`AndroidNotificationDetails` and the manifest's FCM default-icon meta-data.
Copy `receive.wav` into `res/raw/` and point the channel at it.

### 3.4 — Verify end to end

Send a message from an iPhone to an Android device with the app closed.
Confirm: heads-up notification, correct icon, correct sound, and tapping it
opens the right conversation.

---

## Phase 4 — Parity sweep

**Goal: nothing feels second-class.** These are individually small.

* **4.1 Back navigation (Q9).** Hardware back and predictive back across the
  app-lock gate, the walkthrough, the media viewer and the chat. Widget tests
  for the pop handling; a device pass for feel.
* **4.2 16 KB page size (Q8).** Build the AAB and check the Play Console
  bundle report, or run the alignment check locally over the bundled `.so`
  files. If a plugin is non-compliant, the options are upgrade, replace, or
  drop the feature — in that order.
* **4.3 App badge (Q7).** Confirm `AppBadge.set` fails safely on launchers
  that do not support it. Do not chase OEM support. Document it as a known
  platform difference rather than a bug.
* **4.4 Biometric app lock.** `local_auth` on Android, including the passcode
  fallback that is mandatory per the App Lock decision, and the `paused`
  versus `inactive` lifecycle distinction that bit iOS (PR #434).
* **4.5 The image editor and gallery.** `pro_image_editor` and
  `wechat_assets_picker` both have Android quirks around permissions and file
  URIs. The WhatsApp-style layout (PR #443) needs a visual check.
* **4.6 Fonts, layout and dark mode** on a 16:9 and a tall 20:9 device.
* **4.7 Video playback and compression**, which is where Android fragmentation
  most often shows up.

---

## Phase 5 — Analytics and Data Safety

**Goal: the numbers keep working, and the store declaration is honest.**

### 5.1 — Analytics needs almost nothing

This is the payoff from building the analytics platform platform-neutrally.
`platform: android` is already reported, every event is Dart-side, and both
PostHog and Sentry support Android.

Two things to verify rather than assume:

* **`country` comes from the device locale** on Android as it does on iOS, and
  PostHog's IP geolocation stays disabled (there is already a test pinning
  `$geoip_disable`).
* **`distinct_id` remains the salted hash** and no Android-specific identifier
  leaks in.

Then **segment every existing dashboard by `platform`**. The first real
question after launch is "do Android users behave differently", and the
digest already carries the property to answer it.

**Worth adding:** a `platform` breakdown line in
`scripts/analytics/growth_digest.py`, mirroring the country section. Cheap, and
it is the number this whole project will be judged on.

### 5.2 — Data Safety form (S2)

Mirror the iOS App Privacy declaration, which is already written out in
`docs/analytics/app-store-privacy-declaration.md`. The Play form asks the same
questions differently:

| Category | Collected | Shared | Purpose |
|---|---|---|---|
| App activity (interactions, screen views) | yes | no | Analytics |
| App info and performance (crash, diagnostics) | yes | no | Analytics, App functionality |
| Messages | yes | no | App functionality — *already true today* |
| Photos and videos | yes | no | App functionality |
| Contacts | yes | no | App functionality |
| Personal info (name, email) | yes | no | Account management |

**The traps, in order of how easily they are missed:**

1. **Third-party SDKs count as your collection.** PostHog and Sentry are
   service providers processing on Reacti's behalf, so they are *collected*
   and **not** *shared* — but they must appear.
2. **Device IDs.** If the PostHog or Sentry Android SDK reads
   `Settings.Secure.ANDROID_ID`, "Device or other IDs" must be declared. This
   needs **checking in the SDK**, not guessing. It is the difference between an
   accurate form and a false one.
3. Data must be declared as **encrypted in transit** (true — HTTPS
   everywhere) and a **deletion route** offered (true — the app has
   delete-account, which is also a Play requirement in its own right).

---

## Phase 6 — CI, signing, and the release pipeline

**Goal: Android ships the same way iOS does, with the same guard rails.**

### 6.1 — A staging flavor (Q4, Q5)

Mirror the iOS arrangement exactly, because the whole staging discipline
depends on having two installable apps side by side:

* `productFlavors { staging { applicationIdSuffix = ".staging" } ; production { } }`
* A distinct app name and the amber icon for staging.
* Register `com.reacti.app.staging` in the Firebase project and add the second
  client to `google-services.json`.
* The staging flavor declares **only** the staging App Links host.

### 6.2 — Workflows

Three new workflows, modelled on the iOS ones that already work:

| Workflow | Trigger | Does |
|---|---|---|
| `android-internal.yml` | `workflow_dispatch` | Builds a signed **staging** AAB, uploads to the Play **internal testing** track |
| `android-release.yml` | `v*` tag push | Builds a signed **production** AAB, uploads to the **closed/production** track as a draft |
| `flutter-ci.yml` (edit) | every PR | Also build a **release** AAB, not only a debug APK — B1 would have been caught on day one by this |

Upload via the Play Developer API with a service-account JSON in GitHub
secrets. That JSON is a service-account key: gitignored, `gh secret set` only,
never committed — the rule already in `CLAUDE.md`.

### 6.3 — Version alignment

`versionCode` must increase on every upload. Reuse the existing convention:
`versionName` from `pubspec.yaml`, `versionCode` from the run number, matching
how `ios-testflight.yml` derives build numbers.

---

## Phase 7 — Store listing and policy declarations

**Goal: survive review.** Mostly Achia's work, with drafting help.

### 7.1 — The Photo & Video Permissions declaration (S1) — highest risk

Google began rejecting releases under this policy on **2026-09-24**. The app
uses a **custom gallery** rather than the system Photo Picker, which is
precisely what the policy targets.

Two routes, and the choice is a product decision:

* **Route A — justify the custom picker.** Submit the declaration form arguing
  the system picker is insufficient for core functionality. The honest argument
  is real: Reacti's send flow is multi-select with a **shared caption and a
  review step** (the WhatsApp media rebuild, PR #344), which the system picker
  cannot express. Risk: the reviewer disagrees, and the release is blocked.
* **Route B — use the system Photo Picker on Android.** Drops
  `READ_MEDIA_IMAGES`/`VIDEO` entirely and removes the policy question. Costs
  the multi-select-with-caption flow on Android, so the two platforms diverge.

**Recommendation: prepare Route A, and have Route B costed before submitting.**
Do not discover the answer to this during the production review, after the
14-day tester clock has already run.

### 7.2 — The Deceptive Behavior angle (P3)

A reviewer who sees "records the front camera without a preview" and nothing
else will reject the app. Make the consent obvious *in the listing itself*: the
store description should say plainly that Reacti captures the recipient's
reaction when they open a message and sends it back to the sender, because
that is the entire point of the product rather than a hidden behaviour.

The in-app disclosure work already done for iOS (the DG1 consent flow, and the
camera primer that explains before the OS prompt) is the evidence that this is
consensual. Reference it in the review notes.

### 7.3 — The listing itself

Screenshots (phone, 7-inch, 10-inch), a feature graphic, short and full
descriptions, the privacy policy URL, a content rating questionnaire (the age
answer must match the **16+** already set on the App Store), and the target
audience declaration.

---

## Phase 8 — Closed test, then production

1. Upload the first signed AAB to the **internal** track. Confirm it installs
   from Play, which catches signing and bundle problems immediately.
2. Read the **pre-launch report** — Google runs the app on real devices and
   reports crashes, accessibility and 16 KB issues for free. Expect findings.
3. Pull the app signing SHA-256 and publish `assetlinks.json` (3.1). Verify
   App Links.
4. Move to the **closed** track and open it to the twelve testers.
5. **Wait fourteen days.** Use them for Phase 4 device testing and to watch the
   Android analytics arrive.
6. Apply for production access, submit, and expect a review of a few days.

---

## Risks, ranked

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Photo & Video Permissions rejection** (S1) | High — enforcement began four days ago | Blocks release | Decide Route A vs B in Phase 0, not at submission |
| **The 14-day tester clock** (B6) | Certain if personal account | 2+ weeks of calendar | Start Phase 8 step 1 as early as possible; it only needs an installable build, not a finished one |
| **Patent flow wrong-camera** (P1) | High on some devices | Core feature broken, invisibly | Fix in Phase 2 and test on physical devices, plural |
| Deceptive Behavior review (P3) | Medium | Blocks release, appealable | Listing copy and review notes in Phase 7 |
| A plugin fails 16 KB (Q8) | Medium | Blocks upload | Check early (Phase 4.2), in parallel with other work |
| App Links broken at launch | Medium | Invite loop degraded | Known ordering problem; fix right after first upload |
| Android device fragmentation | Certain | Many small bugs | Phase 4, plus the pre-launch report |

---

## What this plan deliberately does not do

* **No Android-first features.** Parity with iOS, nothing more. Widgets,
  Wear OS, tablets-as-a-target and Android Auto are all out.
* **No backend rewrite.** Two additive backend changes only:
  `assetlinks.json` and the FCM `AndroidConfig`. No response shape changes, so
  no old-app risk and no need to re-run the app-first dance beyond the normal
  deploy order.
* **No Play Billing.** Reacti has no payments.
* **No F-Droid, Amazon, Huawei or APK-direct distribution.**
* **It does not touch the parked work** (`friend_added` fix, demo copy,
  wireframe F5/F1). Those still ship with the next release on their own
  schedule.

---

## Effort, honestly

Phases 1–6 are roughly **three to four weeks of engineering**, assuming
Android devices are available for testing. Phases 0, 7 and 8 are largely
Achia's and Google's time, and the 14-day tester window runs in parallel with
Phase 4 rather than after it.

The realistic calendar from go-ahead to a live Play listing is **five to seven
weeks**, dominated by the tester clock and the review, not by the code.

The single best way to shorten it is to **start Phase 0 today** and get an
installable build onto the internal track before Phase 2 is finished.

---

## Sources

Play policy positions were checked on 2026-09-28 rather than recalled:

- [Meet Google Play's target API level requirement](https://developer.android.com/google/play/requirements/target-sdk)
- [Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Details on Google Play's Photo and Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/14115180?hl=en)
- [Required actions to comply with the Photo & Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/15800983?hl=en)
- [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Deceptive Behavior policy](https://play.google.com/about/privacy-security-deception/deceptive-behavior/dishonest-behavior/)
- [Prepare your apps for Google Play's 16 KB page size requirement](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html)
- [Grant partial access to photos and videos](https://developer.android.com/about/versions/14/changes/partial-photo-video-access)
