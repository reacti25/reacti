#!/usr/bin/env bash
# Runs app/integration_test/android_device_test.dart on the running emulator,
# playing the user's part from the host where Dart cannot reach:
#
#   * grants CAMERA and RECORD_AUDIO the moment the test build is installed
#     (the test waits for them; there is nobody to tap "Allow");
#   * watches for the system Photo Picker, records whether any permission
#     prompt appeared while the gallery was opening, then presses Back.
#
# Fails when the Dart test fails, when the photo picker never opened, or when a
# permission prompt appeared (Step 7: the system picker needs no permission).
# Plan: docs/PLAN-android-and-play-store-2026-09-28.md, Steps 5 and 7.
#
# Usage (from the repo root, emulator running): android_integration.sh
set -uo pipefail

pkg=com.reacti.app
marks=/tmp/android-checks
rm -rf "$marks" && mkdir -p "$marks"
# Start clean, so the grants below land on the test build, not a leftover.
adb uninstall "$pkg" > /dev/null 2>&1 || true

# Grant as soon as `flutter test` has installed the app.
(
  for _ in $(seq 1 900); do
    if adb shell pm list packages "$pkg" | tr -d '\r' | grep -qx "package:$pkg"; then
      adb shell pm grant "$pkg" android.permission.CAMERA
      adb shell pm grant "$pkg" android.permission.RECORD_AUDIO
      exit 0
    fi
    sleep 1
  done
) &
granter=$!

# Play the user in the photo picker.
(
  for _ in $(seq 1 1200); do
    activities=$(adb shell dumpsys activity activities 2> /dev/null)
    grep -q GrantPermissionsActivity <<< "$activities" && touch "$marks/permission_prompt"
    if grep -qi photopicker <<< "$activities"; then
      touch "$marks/picker_opened"
      sleep 3 # let it settle, as a person would
      adb shell input keyevent KEYCODE_BACK
      exit 0
    fi
    sleep 1
  done
) &
watcher=$!

(cd app && flutter test integration_test/android_device_test.dart \
  -d emulator-5554 --reporter expanded)
status=$?
kill "$granter" "$watcher" 2> /dev/null || true

if [ ! -f "$marks/picker_opened" ]; then
  echo "::error::the system Photo Picker never opened (Step 7)"
  status=1
fi
if [ -f "$marks/permission_prompt" ]; then
  echo "::error::a permission prompt appeared during the device test (camera and mic were pre-granted; the photo picker needs none)"
  status=1
fi
exit "$status"
