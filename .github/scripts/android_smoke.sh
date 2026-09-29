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
#   * the app's process is gone.
#
# Usage: android_smoke.sh <apk> <package>
#   android_smoke.sh app-release.apk com.reacti.app
# Leaves smoke.png (screenshot) and logcat.txt in the working directory for the
# workflow to upload as evidence.
#
# Runs as one file because android-emulator-runner executes its `script:`
# input line by line, so multi-line logic there loses its variables.
set -euo pipefail

apk="$1"
pkg="$2"
# Long enough for Flutter's first frame plus Firebase init on a CI emulator.
settle_seconds=30

adb install -r "$apk"
adb logcat -c

# Resolve the launcher activity instead of hardcoding it, so this keeps working
# when flavors add a package suffix (the activity class name does not change).
activity=$(adb shell cmd package resolve-activity --brief "$pkg" | tail -n 1 | tr -d '\r')
echo "Launching $activity"
adb shell am start -W -n "$activity"
sleep "$settle_seconds"

adb exec-out screencap -p > smoke.png || true
adb logcat -d > logcat.txt

failed=0
if ! adb shell pidof "$pkg" > /dev/null; then
  echo "::error::$pkg is not running ${settle_seconds}s after launch"
  failed=1
fi
if grep -E "FATAL EXCEPTION|Unhandled Exception" logcat.txt; then
  echo "::error::crash found in logcat (see the android-smoke artifact)"
  failed=1
fi
[ "$failed" -eq 0 ] && echo "Smoke passed: $pkg launched and stayed up."
exit "$failed"
