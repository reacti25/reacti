#!/usr/bin/env bash
#
# seed-staging-from-prod.sh
#
# Mysqldumps the production Reacti database, loads it into the staging
# database on the same VPS, and scrubs personally-identifying fields so
# staging never holds real user emails, phone numbers, names, or active
# auth tokens.
#
# Run as root on the VPS — needs to read both .env files (which are
# mode 600, owner-only) and write to both databases.
#
# Usage:
#   sudo bash /home/reacti-staging/htdocs/staging.reacti.io/scripts/seed-staging-from-prod.sh
#
# Or once-a-week via cron:
#   0 3 * * 1  root  /home/reacti-staging/htdocs/staging.reacti.io/scripts/seed-staging-from-prod.sh >/var/log/reacti-seed.log 2>&1
#
# Phase 2 deliverable 2.9 of docs/PLAN-staging-and-testing-2026-05-24.md.
#
# Schema-specific TODOs — re-check this list each time prod migrations
# add a new PII-bearing column:
#   - users.email, users.phone, users.name        (current)
#   - personal_access_tokens                       (auth — cleared)
#   - device_tokens, fcm_tokens                    (push — cleared if present)
#   - any new column added by a future migration   <- add here

set -euo pipefail

PROD_DIR=/home/reacti/htdocs/reacti.io
STAGING_DIR=/home/reacti-staging/htdocs/staging.reacti.io

if [[ ! -f "$PROD_DIR/.env" ]]; then
  echo "ERROR: production .env not found at $PROD_DIR/.env" >&2
  exit 1
fi
if [[ ! -f "$STAGING_DIR/.env" ]]; then
  echo "ERROR: staging .env not found at $STAGING_DIR/.env" >&2
  exit 1
fi

# env_value KEY FILE — extract a KEY=value line and strip surrounding quotes.
# Tolerant of either single, double, or no quotes around the value.
env_value() {
  local key=$1 file=$2
  grep -E "^${key}=" "$file" \
    | head -n1 \
    | cut -d= -f2- \
    | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

PROD_DB=$(env_value DB_DATABASE "$PROD_DIR/.env")
PROD_USER=$(env_value DB_USERNAME "$PROD_DIR/.env")
PROD_PASS=$(env_value DB_PASSWORD "$PROD_DIR/.env")

STAGING_DB=$(env_value DB_DATABASE "$STAGING_DIR/.env")
STAGING_USER=$(env_value DB_USERNAME "$STAGING_DIR/.env")
STAGING_PASS=$(env_value DB_PASSWORD "$STAGING_DIR/.env")

if [[ -z "$PROD_DB" || -z "$PROD_USER" || -z "$PROD_PASS" ]]; then
  echo "ERROR: failed to parse prod DB credentials from $PROD_DIR/.env" >&2
  exit 1
fi
if [[ -z "$STAGING_DB" || -z "$STAGING_USER" || -z "$STAGING_PASS" ]]; then
  echo "ERROR: failed to parse staging DB credentials from $STAGING_DIR/.env" >&2
  exit 1
fi

# Safety: refuse to run if prod and staging DBs are somehow the same.
if [[ "$PROD_DB" == "$STAGING_DB" ]]; then
  echo "ERROR: production and staging DB names are identical ($PROD_DB). Aborting." >&2
  exit 1
fi

TMPDUMP=$(mktemp /tmp/reacti-prod-dump-XXXXXX.sql)
# Shred the dump on exit regardless of success — it contains prod PII
# until the staging-side scrub completes, and even after, the unscrubbed
# original shouldn't linger on disk.
trap 'shred -u "$TMPDUMP" 2>/dev/null || rm -f "$TMPDUMP"' EXIT

echo "--- $(date -u +%FT%TZ)  Dumping production DB ($PROD_DB) ---"
mysqldump \
  --user="$PROD_USER" --password="$PROD_PASS" \
  --single-transaction --quick --no-tablespaces \
  --routines --triggers --events \
  "$PROD_DB" > "$TMPDUMP"

echo "--- $(date -u +%FT%TZ)  Wiping staging DB ($STAGING_DB) ---"
# Drop+recreate is simpler than diffing and respects schema changes that
# may have happened in prod since the last seed.
mysql --user="$STAGING_USER" --password="$STAGING_PASS" -e \
  "DROP DATABASE IF EXISTS \`$STAGING_DB\`; CREATE DATABASE \`$STAGING_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "--- $(date -u +%FT%TZ)  Loading dump into staging DB ($STAGING_DB) ---"
mysql --user="$STAGING_USER" --password="$STAGING_PASS" "$STAGING_DB" < "$TMPDUMP"

echo "--- $(date -u +%FT%TZ)  Scrubbing PII in staging ---"
# Each scrub statement is its own mysql invocation with `-f` (force) so a
# missing column / table on a particular deploy doesn't abort the whole
# seed — a warning is logged and the next scrub runs.
scrub() {
  local sql=$1
  mysql -f --user="$STAGING_USER" --password="$STAGING_PASS" "$STAGING_DB" -e "$sql" 2>&1 \
    | grep -v 'Using a password on the command line' || true
}

# Email: deterministic per-user so test logins are reproducible across reseeds.
scrub "UPDATE users SET email = CONCAT('user', id, '@staging.example') WHERE email IS NOT NULL;"

# Phone: 555-prefixed (NANP fictitious range), id-derived for uniqueness.
scrub "UPDATE users SET phone = CONCAT('+1555', LPAD(id, 7, '0')) WHERE phone IS NOT NULL;"

# Name: generic, id-derived.
scrub "UPDATE users SET name = CONCAT('Staging User ', id) WHERE name IS NOT NULL;"

# Personal access tokens (Sanctum) — clear so prod tokens can't authenticate
# against staging by mistake.
scrub "DELETE FROM personal_access_tokens;"

# Push notification tokens — clear so staging never pushes to real devices.
# These tables may not exist on every schema version; `mysql -f` makes the
# missing-table case a warning, not a fatal error.
scrub "TRUNCATE TABLE device_tokens;"
scrub "TRUNCATE TABLE fcm_tokens;"

echo "--- $(date -u +%FT%TZ)  Seed complete ---"
