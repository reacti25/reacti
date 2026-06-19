<?php

/*
|--------------------------------------------------------------------------
| Analytics configuration (Phase 0 scaffolding)
|--------------------------------------------------------------------------
|
| Per-environment settings for the analytics foundation (PostHog product
| analytics + Sentry errors/performance). This is the config seam only — the
| `Analytics` emitter and SDK wiring that consume it land in Phase 1 and are
| staging-verified before any production use.
|
| Plan: docs/PLAN-analytics-stats-2026-06-14.md. Catalog (allowlist source of
| truth): docs/analytics/event-catalog.md.
|
| Default-off by design: with no env vars set, 'enabled' is false and no events
| are emitted, so existing behaviour is unchanged. Real keys come from the
| environment (.env / host secrets), never from the repo. Separate PostHog
| projects + Sentry environments are used for prod vs staging, selected by
| ANALYTICS_ENV. (sentry-laravel publishes its own config/sentry.php in Phase 1;
| this file holds the abstraction's settings.)
|
*/

return [

    // Environment label: 'production' or 'staging'. Labels events and keeps the
    // two projects' data from ever mixing. Falls back to the app environment.
    'env' => env('ANALYTICS_ENV', env('APP_ENV', 'production')),

    // Master switch. Off unless a PostHog key is configured — the default-off
    // guarantee. The Phase 1 emitter checks this before doing any work.
    'enabled' => filled(env('POSTHOG_KEY')),

    // Fraction of server events/spans to sample (0.0–1.0). Keeps analytics from
    // adding load at scale; analytics is fire-and-forget regardless.
    'sample_rate' => (float) env('ANALYTICS_SAMPLE_RATE', 1.0),

    'posthog' => [
        // PostHog project API key (server-side). Empty = product analytics off.
        'key' => env('POSTHOG_KEY'),
        // EU cloud region by default (data-residency requirement of the plan).
        'host' => env('POSTHOG_HOST', 'https://eu.i.posthog.com'),
    ],

    'sentry' => [
        // sentry-laravel reads SENTRY_LARAVEL_DSN itself; mirrored here so the
        // abstraction can report whether error/perf reporting is configured.
        'dsn' => env('SENTRY_LARAVEL_DSN'),
        // Performance trace sample rate; light by default.
        'traces_sample_rate' => (float) env('SENTRY_TRACES_SAMPLE_RATE', 0.1),
    ],

    // Server-side salt used to hash the authenticated user id into the
    // pseudonymous `distinct_id` before any event leaves the server. Never the
    // raw user id. Set per-environment via the environment, never committed.
    'hash_salt' => env('ANALYTICS_HASH_SALT'),

];
