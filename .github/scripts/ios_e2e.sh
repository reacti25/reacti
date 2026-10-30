#!/usr/bin/env bash
# Testing lab, iPhone: runs the device journeys on a booted iOS simulator,
# against the test server from e2e_backend.sh, each on a fresh install.
# Plan: docs/PLAN-device-testing-2026-10-29.md.
#
# The simulator shares the Mac's localhost, so the server's own URLs work
# as they are. The host:
#   * grants camera, microphone, photos and contacts before each install
#     (system prompts cannot be tapped from Dart, and changing a running
#     app's permissions makes iOS kill it, losing the test);
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

# Grants the privacy permissions by bundle id, ready for the next install.
# simctl cannot grant notifications; applesimutils (installed by the
# workflow) can, or iOS's own prompt covers the app.
grant_permissions() {
  for service in camera microphone photos contacts; do
    xcrun simctl privacy "$sim" grant "$service" "$app"
  done
  applesimutils --byId "$sim" --bundle "$app" --setPermissions notifications=YES
}

# Stops the API only (the listening socket's owner; the app's own connections
# to it are the simulator's, which must live).
stop_api() {
  # artisan serve, and the `php -S 0.0.0.0:8000` server it runs.
  pkill -f 'artisan serve' || true
  pkill -f '0.0.0.0:8000' || true
  for _ in $(seq 10); do
    curl -s -o /dev/null --max-time 1 http://127.0.0.1:8000/api/check || return 0
    sleep 1
  done
  echo "the API would not stop" >&2
}

# Starts the API again (unless it is up) and waits until it answers.
start_api() {
  curl -s -o /dev/null http://127.0.0.1:8000/api/check && return 0
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
    # Keep showing a matching face for 12s, as a person keeps looking at the
    # phone: a single match sent before the Face ID sheet is ready is lost and
    # leaves the prompt hanging. In the background, so output keeps flowing.
    unlock) (for _ in 1 2 3 4 5 6; do sleep 2
      xcrun simctl spawn "$sim" notifyutil -p com.apple.BiometricKit_Sim.pearl.match; done) & ;;
    # Opening another app sends ours to the background.
    home) xcrun simctl launch "$sim" com.apple.Preferences ;;
    launch) xcrun simctl launch "$sim" "$app" ;;
    # The code the server just mailed (signup or password reset): see
    # publish_otp in e2e_env.sh.
    otp) publish_otp "$2" ;;
    screenshot) xcrun simctl io "$sim" screenshot "lab-shots/$journey-${2:-$(date +%s)}.png" ;;
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
  grant_permissions
  # 20 minutes each (the first includes the Xcode build); a journey that
  # hangs fails instead of holding the lab. macOS has no `timeout`.
  (cd app && perl -e 'alarm shift; exec @ARGV' 1200 flutter test "$1" -d "$sim" --reporter expanded \
    "${E2E_DEFINES[@]}") | serve_host_requests
  return "${PIPESTATUS[0]}"
}

mkdir -p lab-shots
# What the journeys find on the phone: a photo and a video in the library
# (media_send) and "Smoke Echo" in the contacts (contacts, smoke-e's number).
xcrun simctl addmedia "$sim" app/assets/images/on_board_image1.png app/assets/demo/friend_moment.mp4
cat > lab-contact.vcf <<'VCARD'
BEGIN:VCARD
VERSION:3.0
N:Echo;Smoke;;;
FN:Smoke Echo
TEL;TYPE=CELL:+15550005
END:VCARD
VCARD
xcrun simctl addmedia "$sim" lab-contact.vcf
# The first Xcode build can take over 20 minutes on a slow runner: do it
# once, unlimited, so each journey's 20-minute cap only covers the journey.
(cd app && flutter build ios --simulator --debug   -t integration_test/patent_loop_test.dart "${E2E_DEFINES[@]}")
failed=0
for journey in signup patent_loop chat_journey message_actions media_send read_receipts notification_tap profile_settings friends contacts social groups screens first_run account offline app_lock; do
  run_journey "integration_test/${journey}_test.dart" || failed=1
done

exit "$failed"
