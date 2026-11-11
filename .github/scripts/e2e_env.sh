# Settings of the throwaway test server for device tests, shared by
# e2e_backend.sh, its check and the device-test runners. Source it:
#   source .github/scripts/e2e_env.sh
# Every value is a throwaway that lives only inside one test run.
export APP_ENV=e2e
export APP_DEBUG=true
# The device reaches the server on its own 127.0.0.1 (adb reverse on Android,
# shared localhost on the iOS simulator), so the server's media URLs work there.
export APP_URL=http://127.0.0.1:8000
export APP_KEY=base64:Y2ktcGxhY2Vob2xkZXIta2V5LTMyLWJ5dGVzLXRlc3Q=
export JWT_SECRET=ci-placeholder-jwt-secret-min-32-chars-long-ok
export DB_CONNECTION=sqlite
export CACHE_STORE=file
export SESSION_DRIVER=file
export QUEUE_CONNECTION=sync
export MAIL_MAILER=log
export BROADCAST_CONNECTION=reverb
export REVERB_APP_ID=e2e
export REVERB_APP_KEY=e2e-key
export REVERB_APP_SECRET=e2e-secret
export REVERB_HOST=127.0.0.1
export REVERB_PORT=8080
export REVERB_SCHEME=http
export STAGING_SEED_PASSWORD=e2e-password-only-in-ci

# How the app under test finds this server (the runners pass them to `flutter test`).
E2E_DEFINES=(
  --dart-define=BASE_URL=http://127.0.0.1:8000/api
  --dart-define=BROADCAST_AUTH_URL=http://127.0.0.1:8000/api/broadcasting/auth
  --dart-define=PUSHER_SCHEME=ws
  --dart-define=PUSHER_HOST=127.0.0.1
  --dart-define=PUSHER_PORT=8080
  "--dart-define=PUSHER_KEY=$REVERB_APP_KEY"
  "--dart-define=E2E_PASSWORD=$STAGING_SEED_PASSWORD"
)

# Publishes the code just mailed to $1 (signup: the cache; password reset: the
# users table) as "EMAIL CODE" in the test server's public folder, where the
# device fetches it (app/integration_test/support/otp.dart). Run from the repo
# root.
publish_otp() {
  (cd backend && php artisan tinker --execute="echo '$1 ' . (cache('register_otp_$1') ?: App\Models\User::where('email', '$1')->value('otp'));" > public/lab-otp.txt)
}

# "No internet" for the app under test is a server it cannot reach, so the
# runners take the API down and bring it back (both phones, the same way).

# Stops the API only (the listening socket's owner; the app's own connections
# to it are the device's, which must live). Run from the repo root.
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

# Starts the API again (unless it is up) and waits until it answers. Run from
# the repo root.
start_api() {
  curl -s -o /dev/null http://127.0.0.1:8000/api/check && return 0
  (cd backend && nohup php artisan serve --host=0.0.0.0 --port=8000 >> ../e2e-api.log 2>&1 &)
  for _ in $(seq 30); do
    curl -s -o /dev/null http://127.0.0.1:8000/api/check && return 0
    sleep 1
  done
}
