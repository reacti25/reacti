#!/usr/bin/env bash
# Android launch smoke test: install a built APK on a running emulator, open
# it, and fail if the app crashes during startup.
#
# Why: the release build shrinks code (R8) and runs plugins in ways a debug
# build never does. A crash there is invisible to `flutter test` and to a
# compile-only CI job. Step 1 of docs/PLAN-android-and-play-store-2026-09-28.md.
#
# Fails when any of these happen within the settle window:
#   * a native crash ("FATAL EXCEPTION" in logcat),
#   * an uncaught Dart error ("Unhandled Exception" from the Flutter engine),
#   * the app's process is gone,
#   * a permission prompt is showing at first launch (Step 3: Android asks for
#     camera and microphone just in time, never cold at launch),
#   * the high-importance notification channel was not created (Step 6).
#
# Usage: android_smoke.sh <apk> <package>
#   android_smoke.sh app-release.apk com.reacti.app
# Leaves smoke-<package>.png (screenshot) and logcat-<package>.txt in the
# working directory for the workflow to upload as evidence.
#
# Runs as one file because android-emulator-runner executes its `script:`
# input line by line, so multi-line logic there loses its variables.
set -euo pipefail

apk="$1"
pkg="$2"
# Long enough for Flutter's first frame plus Firebase init on a CI emulator.
settle_seconds=30

adb install -r "$apk"
# Pre-answer the one prompt that is allowed at launch (notifications), so any
# prompt still showing afterwards can only be the camera/mic one Step 3 forbids.
adb shell pm grant "$pkg" android.permission.POST_NOTIFICATIONS || true
adb logcat -c

# Resolve the launcher activity instead of hardcoding it, so this keeps working
# when flavors add a package suffix (the activity class name does not change).
activity=$(adb shell cmd package resolve-activity --brief "$pkg" | tail -n 1 | tr -d '\r')
echo "Launching $activity"
adb shell am start -W -n "$activity"
sleep "$settle_seconds"

shot="smoke-$pkg.png"
log="logcat-$pkg.txt"
adb exec-out screencap -p > "$shot" || true
adb logcat -d > "$log"

failed=0
if ! adb shell pidof "$pkg" > /dev/null; then
  echo "::error::$pkg is not running ${settle_seconds}s after launch"
  failed=1
fi
if grep -E "FATAL EXCEPTION|Unhandled Exception" "$log"; then
  echo "::error::crash found in logcat (see the android-smoke artifact)"
  failed=1
fi
if adb shell dumpsys activity activities | grep -q GrantPermissionsActivity; then
  echo "::error::a permission prompt is showing at first launch (Step 3)"
  failed=1
fi
# Created at launch by NotificationService; without it Android pushes have no
# banner. Importance 4 (high) or 5 (max) both give a heads-up.
# Scoped to this package: staging and production can be installed together and
# each must create its own channel.
channels=$(adb shell dumpsys notification | tr -d '\r' \
  | awk -v pkg="$pkg" '/AppSettings: /{ cur = $2 } cur == pkg && /NotificationChannel\{/')
if ! grep -qE "mId='high_importance_channel'.*mImportance=(4|5)" <<< "$channels"; then
  echo "::error::$pkg: high_importance_channel missing or not high importance (Step 6)"
  echo "$channels" | head -10
  failed=1
fi
[ "$failed" -eq 0 ] && echo "Smoke passed: $pkg launched and stayed up."
exit "$failed"
