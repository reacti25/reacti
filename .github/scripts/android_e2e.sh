#!/usr/bin/env bash
# Testing lab, Android: runs the device journeys on the running emulator,
# against the test server from e2e_backend.sh, each on a fresh install.
# Plan: docs/PLAN-device-testing-2026-10-29.md.
#
# The host does what nobody is at the emulator to do:
#   * maps the emulator's 127.0.0.1:8000/8080 to the test server, so the
#     server's own URLs (APP_URL=http://127.0.0.1:8000) work on the device;
#   * grants camera, microphone and notifications the moment the test build is
#     installed (system prompts cannot be tapped from Dart);
#   * carries out each "E2E_HOST: <action>" a journey prints
#     (app/integration_test/support/host.dart) with adb.
#
# Usage, from the repo root: android_e2e.sh
set -uo pipefail
source "$(dirname "$0")/e2e_env.sh"

pkg=com.reacti.app
caller=5551234
pin=1111

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

# Carries out one host action (see host.dart for the list).
host_action() {
  set -- $1
  case $1 in
    # Answered, so Android's audio is in call mode, which the app checks.
    call) adb emu gsm call "$caller"; sleep 2; adb emu gsm accept "$caller" ;;
    hangup) adb emu gsm cancel "$caller" ;;
    open) adb shell am start -a android.intent.action.VIEW -d "$2" "$pkg" ;;
    # To the app, a server it cannot reach looks exactly like no internet.
    offline) adb reverse --remove tcp:8000 ;;
    online) adb reverse tcp:8000 tcp:8000 ;;
    lock-setup) adb shell locksettings set-pin "$pin" ;;
    # Give the system unlock screen time to appear, then type the PIN.
    unlock) sleep 3; adb shell input text "$pin"; adb shell input keyevent KEYCODE_ENTER ;;
    home) adb shell input keyevent KEYCODE_HOME ;;
    launch) adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 ;;
    screenshot) adb exec-out screencap -p > "lab-shots/$journey-$(date +%s).png" ;;
    *) echo "unknown host action: $*" >&2 ;;
  esac < /dev/null
}

# Echoes the journey's output and carries out each host request it prints.
serve_host_requests() {
  while IFS= read -r line; do
    printf '%s\n' "$line"
    case $line in
      *'E2E_HOST: '*) host_action "${line#*E2E_HOST: }" ;;
    esac
  done
}

# Runs one journey file on a fresh install; returns its exit status.
run_journey() {
  # Fresh install: no login or grants left over from the previous journey.
  adb uninstall "$pkg" > /dev/null 2>&1 || true
  grant_after_install &
  local granter=$!
  (cd app && flutter test "$1" -d emulator-5554 --reporter expanded \
    "${E2E_DEFINES[@]}") | serve_host_requests
  local status=${PIPESTATUS[0]}
  kill "$granter" 2> /dev/null || true
  return "$status"
}

adb reverse tcp:8000 tcp:8000
adb reverse tcp:8080 tcp:8080

mkdir -p lab-shots
failed=0
for journey in patent_loop chat_journey message_actions profile_settings friends groups call_guard invite_link offline \
  app_lock; do # app_lock last: it leaves a screen-lock PIN on the emulator.
  run_journey "integration_test/${journey}_test.dart" || failed=1
done

exit "$failed"
