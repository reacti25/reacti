#!/usr/bin/env bash
# Testing lab, iPhone: runs the device journeys on a booted iOS simulator,
# against the test server from e2e_backend.sh, each on a fresh install.
# Plan: docs/PLAN-device-testing-2026-10-29.md.
#
# The simulator shares the Mac's localhost, so the server's own URLs work
# as they are. The host:
#   * grants camera, microphone, photos and contacts once the test build is
#     installed (system prompts cannot be tapped from Dart);
#   * carries out each "E2E_HOST: <action>" a journey prints
#     (app/integration_test/support/host.dart) with simctl.
#
# Not run here, because a simulator cannot do it: phone calls (call_guard)
# and invite links (debug builds carry no associated domains).
#
# Usage, from the repo root: ios_e2e.sh <simulator udid>
set -uo pipefail
source "$(dirname "$0")/e2e_env.sh"

sim=$1
app=com.reacti.app

# Grants the privacy permissions as soon as `flutter test` has installed the app.
grant_after_install() {
  for _ in $(seq 1 1800); do
    if xcrun simctl get_app_container "$sim" "$app" > /dev/null 2>&1; then
      for service in camera microphone photos contacts; do
        xcrun simctl privacy "$sim" grant "$service" "$app"
      done
      return 0
    fi
    sleep 1
  done
}

# Stops the API only (the listening socket's owner; the app's own connections
# to it are the simulator's, which must live).
stop_api() {
  pkill -f 'artisan serve' || true
  kill $(lsof -ti tcp:8000 -sTCP:LISTEN) 2> /dev/null || true
}

# Starts the API again and waits until it answers.
start_api() {
  (cd backend && nohup php artisan serve --host=0.0.0.0 --port=8000 >> ../e2e-api.log 2>&1 &)
  for _ in $(seq 30); do
    curl -s -o /dev/null http://127.0.0.1:8000/api/check && return 0
    sleep 1
  done
}

# Carries out one host action (see host.dart for the list).
host_action() {
  set -- $1
  case $1 in
    open) xcrun simctl openurl "$sim" "$2" ;;
    offline) stop_api ;;
    online) start_api ;;
    lock-setup) xcrun simctl spawn "$sim" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
      xcrun simctl spawn "$sim" notifyutil -p com.apple.BiometricKit.enrollmentChanged ;;
    # Give the Face ID sheet time to appear, then show it a matching face.
    unlock) sleep 3; xcrun simctl spawn "$sim" notifyutil -p com.apple.BiometricKit_Sim.pearl.match ;;
    # Opening another app sends ours to the background.
    home) xcrun simctl launch "$sim" com.apple.Preferences ;;
    launch) xcrun simctl launch "$sim" "$app" ;;
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
  xcrun simctl uninstall "$sim" "$app" > /dev/null 2>&1 || true
  grant_after_install &
  local granter=$!
  (cd app && flutter test "$1" -d "$sim" --reporter expanded \
    "${E2E_DEFINES[@]}") | serve_host_requests
  local status=${PIPESTATUS[0]}
  kill "$granter" 2> /dev/null || true
  return "$status"
}

failed=0
for journey in patent_loop chat_journey offline app_lock; do
  run_journey "integration_test/${journey}_test.dart" || failed=1
done

exit "$failed"
