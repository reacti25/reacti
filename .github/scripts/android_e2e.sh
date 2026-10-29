#!/usr/bin/env bash
# Runs one device journey from app/integration_test on the running emulator,
# against the test server from e2e_backend.sh.
# Plan: docs/PLAN-device-testing-2026-10-29.md, phase 2.
#
# The host does what nobody is at the emulator to do:
#   * maps the emulator's 127.0.0.1:8000/8080 to the test server, so the
#     server's own URLs (APP_URL=http://127.0.0.1:8000) work on the device;
#   * grants camera, microphone and notifications the moment the test build is
#     installed (system prompts cannot be tapped from Dart).
#
# Usage, from the repo root: android_e2e.sh integration_test/patent_loop_test.dart
set -uo pipefail
source "$(dirname "$0")/e2e_env.sh"

pkg=com.reacti.app
test_file=$1

adb reverse tcp:8000 tcp:8000
adb reverse tcp:8080 tcp:8080
# Start clean, so the grants below land on the test build, not a leftover.
adb uninstall "$pkg" > /dev/null 2>&1 || true

(
  for _ in $(seq 1 900); do
    if adb shell pm list packages "$pkg" | tr -d '\r' | grep -qx "package:$pkg"; then
      for permission in CAMERA RECORD_AUDIO POST_NOTIFICATIONS; do
        adb shell pm grant "$pkg" "android.permission.$permission"
      done
      exit 0
    fi
    sleep 1
  done
) &
granter=$!

(cd app && flutter test "$test_file" -d emulator-5554 --reporter expanded \
  --dart-define=BASE_URL=http://127.0.0.1:8000/api \
  --dart-define=BROADCAST_AUTH_URL=http://127.0.0.1:8000/api/broadcasting/auth \
  --dart-define=PUSHER_SCHEME=ws \
  --dart-define=PUSHER_HOST=127.0.0.1 \
  --dart-define=PUSHER_PORT=8080 \
  "--dart-define=PUSHER_KEY=$REVERB_APP_KEY" \
  "--dart-define=E2E_PASSWORD=$STAGING_SEED_PASSWORD")
status=$?
kill "$granter" 2> /dev/null || true
exit "$status"
