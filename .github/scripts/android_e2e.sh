#!/usr/bin/env bash
# Runs every device journey in app/integration_test on the running emulator,
# against the test server from e2e_backend.sh, each on a fresh install.
# Plan: docs/PLAN-device-testing-2026-10-29.md, phase 2.
#
# The host does what nobody is at the emulator to do:
#   * maps the emulator's 127.0.0.1:8000/8080 to the test server, so the
#     server's own URLs (APP_URL=http://127.0.0.1:8000) work on the device;
#   * grants camera, microphone and notifications the moment the test build is
#     installed (system prompts cannot be tapped from Dart);
#   * puts the emulator on a phone call for the call-guard journey.
#
# Usage, from the repo root: android_e2e.sh
set -uo pipefail
source "$(dirname "$0")/e2e_env.sh"

pkg=com.reacti.app
phone=5551234

# Grants the runtime permissions as soon as `flutter test` has installed the app.
grant_after_install() {
  for _ in $(seq 1 900); do
    if adb shell pm list packages "$pkg" | tr -d '\r' | grep -qx "package:$pkg"; then
      for permission in CAMERA RECORD_AUDIO POST_NOTIFICATIONS; do
        adb shell pm grant "$pkg" "android.permission.$permission"
      done
      return 0
    fi
    sleep 1
  done
}

# Runs one journey file on a fresh install; returns its exit status.
run_journey() {
  # Fresh install: no login or grants left over from the previous journey.
  adb uninstall "$pkg" > /dev/null 2>&1 || true
  grant_after_install &
  local granter=$!
  (cd app && flutter test "$1" -d emulator-5554 --reporter expanded \
    --dart-define=BASE_URL=http://127.0.0.1:8000/api \
    --dart-define=BROADCAST_AUTH_URL=http://127.0.0.1:8000/api/broadcasting/auth \
    --dart-define=PUSHER_SCHEME=ws \
    --dart-define=PUSHER_HOST=127.0.0.1 \
    --dart-define=PUSHER_PORT=8080 \
    "--dart-define=PUSHER_KEY=$REVERB_APP_KEY" \
    "--dart-define=E2E_PASSWORD=$STAGING_SEED_PASSWORD")
  local status=$?
  kill "$granter" 2> /dev/null || true
  return "$status"
}

adb reverse tcp:8000 tcp:8000
adb reverse tcp:8080 tcp:8080

failed=0
run_journey integration_test/patent_loop_test.dart || failed=1
run_journey integration_test/chat_journey_test.dart || failed=1

# An answered call puts Android's audio in call mode, which the app checks.
adb emu gsm call "$phone"
sleep 2
adb emu gsm accept "$phone"
run_journey integration_test/call_guard_test.dart || failed=1
adb emu gsm cancel "$phone"

exit "$failed"
