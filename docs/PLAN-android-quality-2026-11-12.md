# Plan: Android fast, smooth and fault-free (2026-11-12)

Status: approved by Achia on 2026-11-12 ("Go on start"). Phase 1 is in
progress on branch `feature/android-quality-phase1`; see "Phase 1 progress".
Scope: the Android app only. Production release timing is Achia's call and is
not part of this plan.

## Where Android stands today (production data, 30 days to 2026-11-12)

Read-only pulls from PostHog and Sentry. About 28 Android "people", most of
them closed testers who joined 2026-11-08/09.

**Faults.** Sentry recorded three error types on Android, about 50 events:

| Error | Share | State |
|---|---|---|
| `XmlParserException: name expected at 4:82` (a PNG placeholder drawn as SVG when a photo fails to load) | about half | fixed on develop by #545, ships in 1.8.2 |
| `Null check operator used on a null value` in request error handlers | about a third | fixed on develop by #546, ships in 1.8.2 |
| `type 'String' is not a subtype of type 'int' of 'index'` in request error handlers | the rest | same handlers as #546; believed covered, not proven |

No native Android crash was recorded. The low "crash-free" figure (5 of 8
users on 1.8.1+1003) is these three errors: Sentry SDK 9 counts any unhandled
Dart error as a crash even though the app keeps running.

**Smoothness.** The raw numbers (22% slow frames, freezes over a second) are
skewed by one device: model "OnePlus8Pro", Android 11, 9 accounts, timezone
America/Los_Angeles, screen density 0.66. It holds 72% of all slow frames and
every freeze over 700 ms. It does not look like a real phone (an emulator or
a cloud phone). Without it:

| | Android real phones | iPhone |
|---|---|---|
| Frames over 16 ms | 7.6% | 0.7% |
| Worst frame, p90 | 149 ms | 81 ms |
| Worst frame, max | 592 ms | 1931 ms |
| Cold start p50 / p90 | 236 / 781 ms | 69 / 145 ms |

Worst screen: the chat screen. Worst phone: Redmi 220233L2G (low end,
Android 11), cold start 4.5 s typical, 8.5 s worst.

**The measurement itself is rough.** `frame_jank` counts a frame as slow when
vsync-to-raster-end is over a fixed 16 ms (`frame_jank_reporter.dart`). That
over-counts on Android (build and raster run on two threads) and ignores
90/120 Hz screens. It also cannot say whether Dart code or drawing is slow.

**Other Android findings.** 4 media uploads failed on 1.8.1 (3 videos, 1
photo) with no reason recorded. The selfie video has never run on a real
Android phone. The testing lab runs on an emulator only.

**Build setup checked, nothing wrong found:** release bundle with R8 (Flutter
default), target SDK 36, min SDK 24, 16 KB page check, Impeller renderer on
by default with its automatic fallback, Play test-lab robots excluded from
analytics.

## Phase 1: see the truth (one branch, small)

Goal: numbers we can trust, per phone, before changing any screen.

1. **Frame metric.** Record build time and raster time separately and take
   the budget from the screen's refresh rate. Catalog and allowlist updated
   first (`docs/analytics/event-catalog.md`). Old `frame_jank` fields stay so
   history is comparable.
2. **Health report.** `perf_digest.py` gains a split by Android/iPhone and by
   phone model, and a "top errors" section read from Sentry (the read key in
   `.local-secrets/sentry_reacti_insights_token.txt` can read error titles
   through the organisation events endpoint, not the issues endpoint).
3. **"Crash" means crash.** Move `sentry_flutter` 9 to 10, where an unhandled
   error that leaves the app running no longer counts as a crash. Check its
   requirements first (reported: Flutter 3.44, Android API 26; ours is min
   SDK 24, so this may drop Android 7). If the cost is too high, stay on 9
   and report "errors per session" beside crash-free.
4. **Readable native crashes.** Upload the R8 mapping and native symbols to
   Sentry from `android-release.yml`, so a real Android crash shows names.
5. **Upload failures.** Record the failure reason for a failed media upload
   on Android (it is empty today).
6. **Google's own numbers.** Android vitals and the pre-launch report in Play
   Console are the reference for crashes and ANRs. Needs a way for Claude to
   read them (Achia decides: Chrome, or a read-only Play reporting key).

Exit: one report run shows Android by phone model with build/raster split,
real crash-free, top errors, and upload failure reasons.

### Phase 1 progress (2026-11-12)

Built on the branch (steps 1, 2, 5 and the reporting half of 3):

* **Step 1, done.** `frame_jank` now also carries the refresh rate, slow
  builds and slow rasters counted separately against one refresh interval,
  their longest times, and the frames of the smooth windows in between.
  Found while building it: the old slow-frame percentages were taken over
  the windows that had a slow frame only (smooth windows send nothing), so
  the 7.6% / 0.7% above overstate both platforms. The new
  `quiet_frame_count` fixes the denominator from the next app version on.
* **Step 2, done.** `perf_digest.py` prints the split by OS and by phone
  model and the top Sentry errors, each marked `CRASH` or `kept running`.
  First run, production, 30 days: 1 real crash (an iPhone one), none on
  Android.
* **Step 3, half.** Sentry SDK 10 needs Android API 26 (ours is 24, so it
  drops Android 7), Dart 3.12, and it removes CocoaPods, so the iPhone build
  must move to Swift Package Manager. That is its own piece of work and
  Achia's decision, not part of this branch. Until then the digest's verdict
  column is the real crash figure.
* **Step 5, done differently.** The reason was already recorded, on
  `message_sent`: the 4 failed Android uploads were 1 network drop, 1 server
  error (5xx) and 2 `unknown`. Added `error_type` (the error's class name)
  so an `unknown` says what it was.

Waiting for Achia:

* **Step 4** needs a Sentry upload key stored as a GitHub secret. Play
  Console already receives the R8 mapping inside the bundle, so its own
  crash reports are readable without this.
* **Step 6** needs read access to Play Console.

## Phase 2: real phones before users

Goal: every release candidate runs on real Android hardware.

1. **Device checks on real phones.** Run `android_device_test.dart` (camera
   clip with audio, selfie video mirror, photo picker; needs no server) on
   Firebase Test Lab physical devices: one Samsung A-series (what most
   testers have) and one low-end Android 11 phone. Free tier is 5 physical
   runs a day, so this runs on release candidates, not on every PR.
2. **Journeys on a real phone.** The lab journeys need the test server on the
   same machine, which a cloud phone cannot reach. Design step: point them at
   staging with the seeded smoke accounts, or keep journeys on the emulator
   and use real phones for device checks and performance only.
3. **A phone on the desk (optional, strongest).** One low or mid range
   Android phone on USB lets Claude profile screens directly. Achia decides.

Exit: the selfie video and camera checks pass on two real phones.

## Phase 3: fix by evidence, worst first

Each item: measure with Phase 1 numbers, profile on a real phone, fix, lab
green, re-measure. No guessing from code alone.

1. **Chat screen smoothness** (the worst screen). Suspects to confirm or
   rule out by profiling: image decode size, video players inside the list,
   whole-list rebuilds on each new message.
2. **Cold start on low-end phones.** `main()` waits for Firebase, storage,
   app info, the test-lab check, PostHog, the funnel clock and Sentry before
   the first frame. Move what is not needed for the first screen to after it.
3. **Android media upload failures**, once Phase 1 names the reason.
4. **Photos that fail to load** (the placeholder appeared at least 50 times;
   after #545 it draws quietly, so the cause needs its own look).

Exit: targets below met on mid-range phones for two weeks of data.

## Phase 4: keep it that way

**Targets** (Android, real phones, tune as data grows):

| Measure | Target |
|---|---|
| Crash-free users (real crashes) | 99% or better; Play's own limits are about 1.09% crashes and 0.47% ANRs |
| Unhandled errors | no error type seen by more than 1 user in a week |
| Frames over budget, mid-range | 2% or less |
| Any single frame | under 700 ms |
| Cold start p90, mid-range | under 1.5 s |
| Media upload failures | under 2% |

**Android release gate**, added to the release checklist: lab green, real
phone device checks green, Play pre-launch report clean, last version inside
the targets or the gap explained.

**Weekly:** the health report run once a week, Android line first.

## Rules that apply

All of `docs/RULES.md`. In particular: every step on a branch, lab green,
Achia's yes before any merge into develop and before any staging build;
analytics changes are observation only; the reaction-recording flow is not
touched (if a step would touch it, it gets an end-to-end test first).

## Open questions for Achia

1. Is the "OnePlus8Pro" device known (an emulator, a tester service)?
2. Real phones: Firebase Test Lab (free tier, a setting in the existing
   Firebase project), a phone on the desk, or both?
3. Play Console read access for Claude: Chrome, or a read-only key?

## Sources

- https://docs.flutter.dev/perf/impeller
- https://docs.flutter.dev/perf/metrics
- https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html
- https://developer.android.com/google/play/vitals/anr
- https://firebase.google.com/docs/test-lab/usage-quotas-pricing
- https://blog.sentry.io/flutter-sdk-10/
