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
