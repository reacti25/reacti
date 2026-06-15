# Reacti analytics — privacy

What analytics does and does not collect, and how location is handled. This is a
**face-recording app**, so the bar is: pseudonymous, metadata-only, no way to
pin a person to who/where they are. Enforced in code (see
`docs/analytics/event-catalog.md` and the allowlist tests).

## Never collected
Message text or media, camera frames/clips, names, emails, phone numbers,
avatars, auth tokens, raw user ids, **precise location** (city, GPS, postal code).

## Collected (metadata only)
Allowlisted event properties (counts, type/scope enums, durations in ms, coarse
size buckets), a **salted** pseudonymous `distinct_id` (see below), platform,
app version, session id, timestamp.

## Identity — salted, non-reversible
`distinct_id` is `SHA-256(secret_salt : user_id)` with a high-entropy **secret
per-environment salt** (`ANALYTICS_HASH_SALT`). Reacti user ids are short and
sequential, so a *plain* hash would be brute-forceable; the secret salt prevents
that. If no salt is configured the app emits **no** `distinct_id` (anonymous) —
it never falls back to a reversible unsalted hash.

## Location — IP GeoIP disabled
PostHog Cloud, by default, derives an approximate **city** from the request IP at
ingestion (e.g. it showed "Jerusalem"). For a recording app this is too precise.

**What we do:** every PostHog event is sent with the `$geoip_disable` directive
(`PostHogAnalyticsService.postHogProperties`, pinned by a test), so PostHog
attaches **no** IP-based location at all — no city, no subdivision, **and no
country**. We do not collect GPS either.

**If country-level is wanted (config — Achia):** PostHog has no client-side
"country only" granularity, so keeping an accurate GeoIP country while dropping
city must be done **server-side in the PostHog project**, not in the app:
1. Remove the `$geoip_disable` directive (so GeoIP runs again), **and**
2. In the PostHog project, add an ingestion **transformation / property filter**
   that drops `$geoip_city_name`, `$geoip_subdivision_1_name`,
   `$geoip_subdivision_1_code`, `$geoip_subdivision_2_*`, `$geoip_postal_code`,
   `$geoip_latitude`, `$geoip_longitude`, `$geoip_city_confidence`,
   `$geoip_time_zone`, while keeping `$geoip_country_name`/`$geoip_country_code`
   and `$geoip_continent_*`.

Until that project transformation is in place, IP GeoIP stays **fully off** (the
safe default). This requires a PostHog **personal** API key / dashboard access,
which the app's project key does not have — so it is Achia's one-time config.

## Production activation (when enabled — currently OFF)

Production analytics is **off by default and never emits an unsalted id**, by
construction:

- **App:** the prod build (`ios-release.yml`) passes **no** analytics
  `--dart-define`s, so `AnalyticsConfig.analyticsEnabled` is false → nothing is
  emitted. Prod App Store users have never run an analytics-enabled build, so
  there is no unsalted residue to clean.
- **Backend:** `backend-deploy.yml` does **not** inject the analytics env, so
  `config('analytics.enabled')` is false → nothing is emitted.
- **Code guarantee (both ends, tested):** with no salt configured, no
  `distinct_id` is attached at all (anonymous) — an unsalted, brute-forceable
  hash is *never* produced, even on misconfiguration.

To enable production analytics later, wire a **separate prod salt** the same way
staging is wired (a different salt per env so ids never cross-reference):

1. Generate a prod salt and store it as the GitHub secret
   `ANALYTICS_HASH_SALT_PROD` (`gh secret set`, never pasted).
2. **App** — in `ios-release.yml`'s build step, add the prod defines:
   `--dart-define=ANALYTICS_ENV=production`, `POSTHOG_KEY`, `POSTHOG_HOST`,
   `SENTRY_DSN`, and `ANALYTICS_HASH_SALT=$ANALYTICS_HASH_SALT_PROD`.
3. **Backend** — add an analytics-env-sync step to `backend-deploy.yml`
   mirroring `staging-deploy.yml`, with `ANALYTICS_ENV=production` and
   `ANALYTICS_HASH_SALT=${{ secrets.ANALYTICS_HASH_SALT_PROD }}` so the prod app
   and prod backend share one `distinct_id`.
4. App-first + staging-verified, per the release playbook; this is a deliberate
   step gated on Achia, never auto-enabled.

## Region & retention
EU data region for PostHog + Sentry. Retention window and the vendor DPAs are
Achia's to set (Phase 4 governance).

## Consent
The analytics opt-out (Phase 4) ties into the DG1 recording-consent context; when
a user opts out, analytics is disabled for them.
