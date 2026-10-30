#!/usr/bin/env bash
# Boots a throwaway Reacti backend for device tests (docs/PLAN-device-testing-2026-10-29.md, phase 1).
#
# API on :8000, Reverb (live updates) on :8080, a fresh sqlite file holding
# only the two smoke accounts and their group. Plain processes, no Docker:
# GitHub's macOS runners have no service containers, and the iOS simulator
# job will boot this same script.
#
# Settings come from e2e_env.sh (sourced below). Logs go to e2e-api.log and e2e-reverb.log in the
# repo root so a failing job can upload them.
#
# Usage, from the repo root: bash .github/scripts/e2e_backend.sh
set -euo pipefail
source "$(dirname "$0")/e2e_env.sh"

# Polls a URL until it answers anything (any HTTP status means the server is up).
wait_for() {
  for _ in $(seq 60); do
    curl -s -o /dev/null "$1" && return 0
    sleep 1
  done
  echo "Server never came up: $1" >&2
  return 1
}

cd backend
composer install --prefer-dist --no-progress --no-interaction
# dotenv warns on a missing file; e2e_env.sh holds the real values.
touch .env
mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
# Laravel's default sqlite path; gitignored. Emptied so every run starts clean.
: > database/database.sqlite
php artisan migrate --force
php artisan db:seed --class=StagingTestAccountsSeeder --force
# Two strangers for the friends journey, only on this throwaway server:
# smoke-c sends alpha a request, alpha finds smoke-d by username.
php artisan tinker --execute='foreach (["c" => "Charlie", "d" => "Delta"] as $k => $name) {
  App\Models\User::updateOrCreate(["email" => "smoke-$k@reacti.test"], [
    "first_name" => "Smoke", "last_name" => $name, "username" => "smoke_$k",
    "password" => Illuminate\Support\Facades\Hash::make(env("STAGING_SEED_PASSWORD")),
    "status" => "active", "otp_verified_at" => now()]);
}'

nohup php artisan reverb:start --host=0.0.0.0 --port=8080 > ../e2e-reverb.log 2>&1 &
nohup php artisan serve --host=0.0.0.0 --port=8000 > ../e2e-api.log 2>&1 &

wait_for http://127.0.0.1:8000/api/check
wait_for http://127.0.0.1:8080
echo "Test server up: API http://127.0.0.1:8000/api, live updates ws://127.0.0.1:8080"
